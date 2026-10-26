import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../instances/instance_repository.dart';
import '../instances/server_instance.dart';
import '../logging/app_log.dart';
import '../logging/file_log_store.dart';
import '../models/alert.dart';
import '../settings/app_settings.dart';
import '../widgets/home_widget_sync.dart';
import '../widgets/home_widgets.dart';
import 'alert_kind_catalog.dart';
import 'alert_watcher.dart';
import 'local_alert_notifier.dart';

/// Runs the alert check now and then while the app is closed. The real one is
/// [WorkmanagerScheduler]; tests use a fake.
abstract interface class BackgroundScheduler {
  /// Whether this phone can run background checks at all.
  bool get isSupported;

  /// Makes sure the check is scheduled. Safe to call again.
  Future<void> schedule();

  Future<void> cancel();
}

/// A [BackgroundScheduler] for a platform with no background checks.
class NoBackgroundScheduler implements BackgroundScheduler {
  const NoBackgroundScheduler();

  @override
  bool get isSupported => false;

  @override
  Future<void> schedule() async {}

  @override
  Future<void> cancel() async {}
}

const _taskName = 'hu.adrian.truenasmobile.alertCheck';

/// Android WorkManager and iOS BGAppRefreshTask, through the `workmanager`
/// package. Both are the phone's own scheduler: the app asks for a check about
/// every 15 minutes and the phone decides when it really runs. On iOS that can
/// be far less often, and not at all after the app was swiped away.
class WorkmanagerScheduler implements BackgroundScheduler {
  const WorkmanagerScheduler();

  static const interval = Duration(minutes: 15);

  @override
  bool get isSupported => true;

  @override
  Future<void> schedule() async {
    // Every start, not only the first: the saved callback handle can change
    // with an app update.
    await Workmanager().initialize(alertCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: interval,
      // iOS has no frequency; this is the earliest it may run.
      initialDelay: interval,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  @override
  Future<void> cancel() => Workmanager().cancelByUniqueName(_taskName);
}

/// The entry point the phone starts in a fresh isolate for each check. It has
/// no screen and no providers: it reads the settings and the saved servers
/// from secure storage, like the app does, and goes through the same
/// [AlertWatcher].
@pragma('vm:entry-point')
void alertCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await attachLogFile();
    try {
      await runBackgroundAlertCheck();
    } catch (error, stack) {
      // Nothing to retry sooner than the next scheduled run.
      AppLog.instance.error('background', error, stack);
    }
    await AppLog.instance.flush();
    return true;
  });
}

/// One background check. It has two jobs: tell about new alerts (when the
/// user turned alert notifications on) and keep the home screen widgets
/// current (when the user has put one on a home screen). With neither to do
/// it does nothing. Never shows anything in the app, so the app lock has
/// nothing to guard; opening the app from a notification goes through it as
/// usual.
Future<void> runBackgroundAlertCheck({
  KeyValueStore store = const SecureKeyValueStore(),
  AlertNotifier? notifier,
  HomeWidgetsBridge widgets = const PlatformHomeWidgets(),
}) async {
  final settings = await SettingsRepository(store).load();
  final forWidgets = settings.homeWidgets && await widgets.hasWidgets();
  if (!settings.alertNotifications && !forWidgets) return;
  final servers = await InstanceRepository(store).load();
  Locale locale() => settings.language != null
      ? Locale(settings.language!)
      : PlatformDispatcher.instance.locale;
  final watcher = AlertWatcher(
    store: store,
    notifier: notifier ?? LocalAlertNotifier(locale: locale),
  );
  await watcher.check(
    servers,
    minimum: settings.alertLevel,
    // Without the notifications on, alerts are only recorded as seen.
    notify: settings.alertNotifications,
    notifyJobs: settings.jobNotifications,
    muted: settings.mutedAlertKinds,
    widgets: forWidgets
        ? HomeWidgetCollector(
            publisher: HomeWidgetPublisher(
              widgets,
              shortcuts: () => settings.siriShortcuts,
            ),
            locale: locale,
            chosenDefault: settings.defaultServerId,
          )
        : null,
  );
}

/// How [AlertNotificationService.turnOn] ended.
enum AlertTurnOn {
  /// Allowed and scheduled.
  on,

  /// The user does not allow notifications for the app.
  denied,

  /// The phone refused (permission prompt or background task).
  failed,
}

/// Turns the background alert check on and off.
class AlertNotificationService {
  AlertNotificationService({
    required this.scheduler,
    required this.notifier,
    required this.store,
    this.widgets = const NoHomeWidgets(),
  });

  final BackgroundScheduler scheduler;
  final AlertNotifier notifier;
  final KeyValueStore store;

  /// The home screen widgets, which the same background check keeps current.
  final HomeWidgetsBridge widgets;

  bool get isSupported => scheduler.isSupported;

  /// The kinds of alert met so far, for Settings.
  AlertKindCatalog get kinds => AlertKindCatalog(store);

  /// Asks the phone for permission, then schedules the check. Nothing is
  /// scheduled unless the result is [AlertTurnOn.on]. Never throws: a phone
  /// that refuses the permission prompt or the background task is a
  /// [AlertTurnOn.failed], not a crash.
  ///
  /// The alerts the servers already have are recorded first, so only alerts
  /// that come after this moment are news.
  Future<AlertTurnOn> turnOn(
    List<ServerInstance> servers, {
    required AlertSeverity level,
  }) async {
    try {
      if (!await notifier.requestPermission()) return AlertTurnOn.denied;
      // Saved again on purpose: on iOS this moves the servers to storage that
      // the phone can read while it is locked, as the check runs then.
      try {
        await _rewrite(InstanceRepository.storageKey);
      } catch (_) {
        // The servers stay where they were; the check still runs when the
        // phone is unlocked.
      }
      try {
        await AlertWatcher(
          store: store,
          notifier: notifier,
        ).check(servers, minimum: level, notify: false);
      } catch (_) {
        // Servers that are down are recorded by the first background check.
      }
      await scheduler.schedule();
      return AlertTurnOn.on;
    } catch (_) {
      try {
        await scheduler.cancel();
      } catch (_) {}
      return AlertTurnOn.failed;
    }
  }

  /// Stops the alert check. With [keepForWidgets] the schedule stays, since
  /// the same check also keeps the home screen widgets current.
  Future<void> turnOff({bool keepForWidgets = false}) async {
    if (keepForWidgets) return;
    try {
      await scheduler.cancel();
    } catch (_) {
      // Nothing was scheduled, or the phone has already dropped it.
    }
  }

  /// At app start: schedules the check again when something needs it (the
  /// phone may have dropped it, and the callback handle changes with each app
  /// update): alert notifications, or a widget on a home screen. Also called
  /// when a server is open, which is when a widget added in the meantime
  /// first gets data.
  Future<void> resume(AppSettings settings) async {
    if (!isSupported) return;
    try {
      if (settings.alertNotifications ||
          (settings.homeWidgets && await widgets.hasWidgets())) {
        await scheduler.schedule();
      }
    } catch (_) {
      // Retried at the next start.
    }
  }

  Future<void> _rewrite(String key) async {
    final value = await store.read(key);
    if (value != null) await store.write(key, value);
  }
}

final alertNotificationServiceProvider = Provider<AlertNotificationService>(
  (ref) => AlertNotificationService(
    scheduler: const NoBackgroundScheduler(),
    notifier: const NoAlertNotifier(),
    store: const SecureKeyValueStore(),
  ),
);
