import 'dart:async';
import 'dart:convert';

import '../instances/instance_repository.dart';
import '../instances/server_instance.dart';
import '../models/alert.dart';
import '../session/truenas_session.dart';
import '../widgets/home_widget_sync.dart';
import 'alert_kind_catalog.dart';

/// Shows alerts on the phone. The real one is `LocalAlertNotifier`; tests use
/// a fake.
abstract interface class AlertNotifier {
  /// Asks the phone for permission to show notifications (the system prompt
  /// the first time). True when notifications are allowed.
  Future<bool> requestPermission();

  /// Shows a notification for [alerts], all new on [server].
  Future<void> show(ServerInstance server, List<TrueNasAlert> alerts);
}

/// An [AlertNotifier] for a phone that cannot show notifications.
class NoAlertNotifier implements AlertNotifier {
  const NoAlertNotifier();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> show(ServerInstance server, List<TrueNasAlert> alerts) async {}
}

/// Opens a session for a background check, which cannot ask the user
/// anything: a server that needs a new certificate trust or a 2FA code is
/// skipped until the user opens the app.
Future<TrueNasSession> connectQuietly(ServerInstance server) async {
  final (session, _) = await connectToInstance(
    server,
    confirmCertificate: (_) async => false,
    askOtp: () async => null,
  );
  return session;
}

/// Looks for new alerts on the saved servers and tells the user about them,
/// once each.
///
/// What it has already seen is kept per server (the ids of the alerts that
/// were active), in the same store as the other app data. A server it has not
/// looked at before is only recorded: the alerts that were already there are
/// not news.
class AlertWatcher {
  AlertWatcher({
    required this.store,
    required this.notifier,
    Future<TrueNasSession> Function(ServerInstance)? connect,
    this.timeout = const Duration(seconds: 25),
    this.separateLimit = 3,
  }) : _connect = connect ?? connectQuietly;

  static const _key = 'alertwatch.v1';

  final KeyValueStore store;
  final AlertNotifier notifier;
  final Future<TrueNasSession> Function(ServerInstance) _connect;

  /// How long one server may take. iOS gives a background task about 30
  /// seconds, and the servers are checked side by side.
  final Duration timeout;

  /// Up to this many new alerts on a server get a notification each; more
  /// are folded into one.
  final int separateLimit;

  /// Checks every server in [servers] and notifies for the new alerts at or
  /// above [minimum]. With [notify] off the alerts are only recorded as seen
  /// (used when the feature is turned on, so old alerts stay quiet).
  ///
  /// Alerts whose kind is in [muted] are recorded as seen but not announced.
  ///
  /// With [widgets], the same visit also gathers what the home screen widgets
  /// show (pools, CPU, memory, alerts) and saves it at the end.
  ///
  /// A server that cannot be reached is skipped and tried again next time.
  Future<void> check(
    List<ServerInstance> servers, {
    required AlertSeverity minimum,
    bool notify = true,
    Set<String> muted = const {},
    HomeWidgetCollector? widgets,
  }) async {
    final seen = await _load();
    final next = <String, Set<String>>{};
    final kinds = <AlertKind>[];
    await Future.wait([
      for (final server in servers)
        _checkOne(
          server,
          seen[server.id],
          minimum,
          notify,
          muted,
          widgets,
        ).then((result) {
          // Unreachable: keep what was known.
          final known = result?.ids ?? seen[server.id];
          if (known != null) next[server.id] = known;
          if (result != null) kinds.addAll(result.kinds);
        }),
    ]);
    await widgets?.finish(servers);
    try {
      await AlertKindCatalog(store).record(kinds);
    } catch (_) {
      // The list in Settings is a convenience; the check goes on.
    }
    await store.write(
      _key,
      jsonEncode({for (final e in next.entries) e.key: e.value.toList()}),
    );
  }

  /// The ids of the alerts that are active now and the kinds of alert met, or
  /// null when the server could not be checked (so nothing is forgotten).
  Future<({Set<String> ids, List<AlertKind> kinds})?> _checkOne(
    ServerInstance server,
    Set<String>? seen,
    AlertSeverity minimum,
    bool notify,
    Set<String> muted,
    HomeWidgetCollector? widgets,
  ) async {
    TrueNasSession? session;
    try {
      session = await _connect(server).timeout(timeout);
      final alerts = await session.alerts().timeout(timeout);
      final active = [
        for (final alert in alerts)
          if (!alert.dismissed) alert,
      ];
      final fresh = [
        if (notify && seen != null)
          for (final alert in active)
            if (!seen.contains(alert.id) &&
                !muted.contains(alert.klass) &&
                alert.level.severity.index >= minimum.index)
              alert,
      ];
      // Before anything is shown: a slow answer here must not leave the
      // alerts shown but not recorded.
      final listed = await session.alertKinds().timeout(
        timeout,
        onTimeout: () => const [],
      );
      if (fresh.isNotEmpty) await _show(server, fresh);
      // After the notifications, which matter more when time is short.
      if (widgets != null) {
        await widgets
            .collect(server, session, alerts: alerts)
            .timeout(timeout, onTimeout: () => widgets.markUnreachable(server));
      }
      final kinds = [
        for (final alert in alerts)
          if (alert.klass.isNotEmpty) AlertKind(alert.klass),
        ...listed,
      ];
      return (ids: {for (final alert in active) alert.id}, kinds: kinds);
    } catch (_) {
      widgets?.markUnreachable(server);
      return null;
    } finally {
      unawaited(session?.close().catchError((_) {}));
    }
  }

  /// The most severe first, one notification each up to [separateLimit], else
  /// one for all of them.
  Future<void> _show(ServerInstance server, List<TrueNasAlert> fresh) async {
    final sorted = [...fresh]
      ..sort((a, b) => b.level.index.compareTo(a.level.index));
    if (sorted.length <= separateLimit) {
      for (final alert in sorted) {
        await notifier.show(server, [alert]);
      }
    } else {
      await notifier.show(server, sorted);
    }
  }

  Future<Map<String, Set<String>>> _load() async {
    try {
      final raw = await store.read(_key);
      if (raw == null || raw.isEmpty) return {};
      return {
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
          e.key: {for (final id in e.value as List<dynamic>) id.toString()},
      };
    } catch (_) {
      return {};
    }
  }
}
