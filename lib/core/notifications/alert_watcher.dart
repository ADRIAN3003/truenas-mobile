import 'dart:async';
import 'dart:convert';

import '../instances/instance_repository.dart';
import '../instances/server_instance.dart';
import '../jobs/tracked_job.dart';
import '../logging/app_log.dart';
import '../models/alert.dart';
import '../session/truenas_session.dart';
import '../widgets/home_widget_sync.dart';
import 'alert_kind_catalog.dart';
import 'job_watch.dart';

/// Shows alerts on the phone. The real one is `LocalAlertNotifier`; tests use
/// a fake.
abstract interface class AlertNotifier {
  /// Asks the phone for permission to show notifications (the system prompt
  /// the first time). True when notifications are allowed.
  Future<bool> requestPermission();

  /// Shows a notification for [alerts], all new on [server].
  Future<void> show(ServerInstance server, List<TrueNasAlert> alerts);

  /// Shows a notification for [jobs], all of which just finished (done or
  /// failed) on [server].
  Future<void> showJobs(ServerInstance server, List<TrackedJob> jobs);
}

/// An [AlertNotifier] for a phone that cannot show notifications.
class NoAlertNotifier implements AlertNotifier {
  const NoAlertNotifier();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> show(ServerInstance server, List<TrueNasAlert> alerts) async {}

  @override
  Future<void> showJobs(ServerInstance server, List<TrackedJob> jobs) async {}
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
/// once each. The same visit tells about scrubs, replications and cloud syncs
/// that ended since the last one.
///
/// What it has already seen is kept per server (the ids of the alerts that
/// were active, and where the jobs stood: `jobwatch.v1`), in the same store as
/// the other app data. A server it has not looked at before is only recorded:
/// the alerts and finished jobs that were already there are not news.
class AlertWatcher {
  AlertWatcher({
    required this.store,
    required this.notifier,
    Future<TrueNasSession> Function(ServerInstance)? connect,
    this.timeout = const Duration(seconds: 25),
    this.separateLimit = 3,
  }) : _connect = connect ?? connectQuietly;

  static const _key = 'alertwatch.v1';
  static const _jobKey = 'jobwatch.v1';

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
  /// Jobs that ended are announced only with [notifyJobs] (and [notify]);
  /// otherwise they are recorded as seen all the same, so switching it on
  /// later does not bring old ones back.
  ///
  /// With [widgets], the same visit also gathers what the home screen widgets
  /// show (pools, CPU, memory, alerts) and saves it at the end.
  ///
  /// A server that cannot be reached is skipped and tried again next time.
  Future<void> check(
    List<ServerInstance> servers, {
    required AlertSeverity minimum,
    bool notify = true,
    bool notifyJobs = true,
    Set<String> muted = const {},
    HomeWidgetCollector? widgets,
  }) async {
    final seen = await _load();
    final seenJobs = await _loadJobs();
    final next = <String, Set<String>>{};
    final nextJobs = <String, JobWatchState>{};
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
          seenJobs[server.id],
          notify && notifyJobs,
        ).then((result) {
          // Unreachable: keep what was known.
          final known = result?.ids ?? seen[server.id];
          if (known != null) next[server.id] = known;
          final knownJobs = result?.jobs ?? seenJobs[server.id];
          if (knownJobs != null) nextJobs[server.id] = knownJobs;
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
    await store.write(
      _jobKey,
      jsonEncode({for (final e in nextJobs.entries) e.key: e.value.toJson()}),
    );
  }

  /// The ids of the alerts that are active now, the kinds of alert met and
  /// where the jobs stand (null when they could not be looked at), or null
  /// when the server could not be checked (so nothing is forgotten).
  Future<({Set<String> ids, List<AlertKind> kinds, JobWatchState? jobs})?>
  _checkOne(
    ServerInstance server,
    Set<String>? seen,
    AlertSeverity minimum,
    bool notify,
    Set<String> muted,
    HomeWidgetCollector? widgets,
    JobWatchState? seenJobs,
    bool notifyJobs,
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
      final jobs = await _checkJobs(
        server,
        session,
        seenJobs,
        notifyJobs && seenJobs != null,
      );
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
      return (
        ids: {for (final alert in active) alert.id},
        kinds: kinds,
        jobs: jobs,
      );
    } catch (error) {
      AppLog.instance.warning(
        'background',
        'Check of "${server.name}" failed: $error',
      );
      widgets?.markUnreachable(server);
      return null;
    } finally {
      unawaited(session?.close().catchError((_) {}));
    }
  }

  /// Tells about the jobs that ended and returns where the jobs stand now, or
  /// null when they could not be looked at (the old record then stays, and the
  /// alerts are not held up by it).
  Future<JobWatchState?> _checkJobs(
    ServerInstance server,
    TrueNasSession session,
    JobWatchState? seen,
    bool notify,
  ) async {
    try {
      final result = await watchJobs(session, seen).timeout(timeout);
      if (notify && result.finished.isNotEmpty) {
        final newest = [...result.finished.reversed];
        if (newest.length <= separateLimit) {
          for (final job in newest) {
            await notifier.showJobs(server, [job]);
          }
        } else {
          await notifier.showJobs(server, newest);
        }
      }
      return result.state;
    } catch (error) {
      AppLog.instance.warning(
        'background',
        'Job check of "${server.name}" failed: $error',
      );
      return null;
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

  Future<Map<String, JobWatchState>> _loadJobs() async {
    try {
      final raw = await store.read(_jobKey);
      if (raw == null || raw.isEmpty) return {};
      return {
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
          e.key: JobWatchState.fromJson(e.value as Map<String, dynamic>),
      };
    } catch (_) {
      return {};
    }
  }
}
