import 'dart:ui';

import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../l10n/generated/app_localizations.dart';
import '../instances/server_instance.dart';
import '../models/alert.dart';
import 'alert_watcher.dart';

/// Android's small status bar icon: a white warning triangle in
/// `res/drawable`, kept from shrinking by `res/raw/keep.xml`.
const _androidIcon = 'ic_stat_alert';

/// The channel the alerts are posted in (Android lets the user tune it).
const _channelId = 'alerts';

/// Shows alerts as phone notifications, in the phone's language or the one
/// chosen in the app. Works in the background too: it needs no screen.
class LocalAlertNotifier implements AlertNotifier {
  LocalAlertNotifier({
    FlutterLocalNotificationsPlugin? plugin,
    Locale Function()? locale,
    this.onTap,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _locale = locale ?? (() => PlatformDispatcher.instance.locale);

  /// Called with the server id when the user taps one of the notifications
  /// while the app is running. The background check has no use for it.
  final ValueChanged<String>? onTap;

  final FlutterLocalNotificationsPlugin _plugin;
  final Locale Function() _locale;
  bool _ready = false;

  /// The payload of the notification that started the app, and when it was
  /// read. iOS may also report that same tap through [onTap] just after.
  String? _launchPayload;
  DateTime? _launchRead;

  Future<void> _ensureReady() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_androidIcon),
        // The permission is asked for when the user turns the setting on,
        // not when the app starts.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _tapped,
    );
    _ready = true;
  }

  void _tapped(NotificationResponse response) {
    final server = response.payload;
    if (server == null || server.isEmpty) return;
    final read = _launchRead;
    if (server == _launchPayload &&
        read != null &&
        DateTime.now().difference(read) < const Duration(seconds: 3)) {
      return;
    }
    onTap?.call(server);
  }

  /// Starts listening for taps and returns the server of the notification
  /// that started the app, if the app was started by one.
  /// Never throws: without it the app only loses the shortcut.
  Future<String?> listenForTaps() async {
    try {
      await _ensureReady();
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final payload = launch?.didNotificationLaunchApp == true
          ? launch?.notificationResponse?.payload
          : null;
      if (payload == null || payload.isEmpty) return null;
      _launchPayload = payload;
      _launchRead = DateTime.now();
      return payload;
    } catch (_) {
      return null;
    }
  }

  AppLocalizations get _l10n {
    final locale = _locale();
    return AppLocalizations.delegate.isSupported(locale)
        ? lookupAppLocalizations(locale)
        : lookupAppLocalizations(const Locale('en'));
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureReady();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<void> show(ServerInstance server, List<TrueNasAlert> alerts) async {
    if (alerts.isEmpty) return;
    await _ensureReady();
    final l10n = _l10n;
    final single = alerts.length == 1;
    final body = single
        ? alerts.first.plainMessage
        : l10n.alertNotificationMany(alerts.length);
    await _plugin.show(
      // The same alert shown twice replaces its notification.
      id: _stableId(single ? alerts.first.id : 'many:${server.id}'),
      title: server.name,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          l10n.alertNotificationChannel,
          channelDescription: l10n.alertNotificationChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: _androidIcon,
          groupKey: server.id,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: DarwinNotificationDetails(threadIdentifier: server.id),
      ),
      payload: server.id,
    );
  }
}

/// A notification id from [text] that is the same in every run (unlike
/// `String.hashCode`), so the same alert always lands on the same id.
int _stableId(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
