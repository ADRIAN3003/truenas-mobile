import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../instances/instance_repository.dart';
import '../instances/server_instance.dart';
import '../models/alert.dart';
import '../settings/app_settings.dart';
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
    try {
      await runBackgroundAlertCheck();
    } catch (_) {
      // Nothing to retry sooner than the next scheduled run.
    }
    return true;
  });
}

/// One background check: nothing happens unless the user turned alert
/// notifications on. Never shows anything in the app, so the app lock has
/// nothing to guard; opening the app from a notification goes through it as
/// usual.
Future<void> runBackgroundAlertCheck({
  KeyValueStore store = const SecureKeyValueStore(),
  AlertNotifier? notifier,
}) async {
  final settings = await SettingsRepository(store).load();
  if (!settings.alertNotifications) return;
  final servers = await InstanceRepository(store).load();
  final watcher = AlertWatcher(
    store: store,
    notifier:
        notifier ??
        LocalAlertNotifier(
          locale: () => settings.language != null
              ? Locale(settings.language!)
              : PlatformDispatcher.instance.locale,
        ),
  );
  await watcher.check(
    servers,
    minimum: settings.alertLevel,
    muted: settings.mutedAlertKinds,
  );
}

/// Turns the background alert check on and off.
class AlertNotificationService {
  AlertNotificationService({
    required this.scheduler,
    required this.notifier,
    required this.store,
  });

  final BackgroundScheduler scheduler;
  final AlertNotifier notifier;
  final KeyValueStore store;

  bool get isSupported => scheduler.isSupported;

  /// The kinds of alert met so far, for Settings.
  AlertKindCatalog get kinds => AlertKindCatalog(store);

  /// Asks the phone for permission, then schedules the check. False (and
  /// nothing scheduled) when the user does not allow notifications.
  ///
  /// The alerts the servers already have are recorded first, so only alerts
  /// that come after this moment are news.
  Future<bool> turnOn(
    List<ServerInstance> servers, {
    required AlertSeverity level,
  }) async {
    if (!await notifier.requestPermission()) return false;
    // Saved again on purpose: on iOS this moves the servers to storage that
    // the phone can read while it is locked, as the check runs then.
    await _rewrite(InstanceRepository.storageKey);
    try {
      await AlertWatcher(
        store: store,
        notifier: notifier,
      ).check(servers, minimum: level, notify: false);
    } catch (_) {
      // Servers that are down are recorded by the first background check.
    }
    await scheduler.schedule();
    return true;
  }

  Future<void> turnOff() => scheduler.cancel();

  /// At app start: schedules the check again when it is on (the phone may
  /// have dropped it, and the callback handle changes with each app update).
  Future<void> resume(AppSettings settings) async {
    if (!settings.alertNotifications || !isSupported) return;
    try {
      await scheduler.schedule();
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
