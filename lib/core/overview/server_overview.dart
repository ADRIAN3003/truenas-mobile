import 'dart:async';

import '../api/api_exception.dart';
import '../instances/server_instance.dart';
import '../logging/app_log.dart';
import '../models/alert.dart';
import '../models/job.dart';
import '../models/pool_summary.dart';
import '../notifications/alert_watcher.dart';
import '../session/truenas_session.dart';

/// How well a server is doing, worst of its pools and alerts.
enum OverviewLevel { ok, attention, problem }

/// What the overview shows about one server, from one visit.
class ServerSnapshot {
  const ServerSnapshot({
    required this.pools,
    required this.alerts,
    required this.jobs,
  });

  final List<PoolSummary> pools;

  /// The alerts that have not been dismissed, most severe first.
  final List<TrueNasAlert> alerts;

  /// The jobs that are waiting or running.
  final List<TrueNasJob> jobs;

  int get poolsNeedingAttention =>
      pools.where((p) => p.condition != PoolCondition.ok).length;

  int get criticalAlerts =>
      alerts.where((a) => a.level.severity == AlertSeverity.critical).length;

  int get warningAlerts =>
      alerts.where((a) => a.level.severity == AlertSeverity.warning).length;

  OverviewLevel get level {
    if (pools.any((p) => p.condition == PoolCondition.down) ||
        criticalAlerts > 0) {
      return OverviewLevel.problem;
    }
    if (poolsNeedingAttention > 0 || warningAlerts > 0) {
      return OverviewLevel.attention;
    }
    return OverviewLevel.ok;
  }
}

/// Why a server could not be looked at.
enum OverviewProblem {
  /// It needs a certificate to be trusted or a 2FA code, which only the
  /// server's own screen can ask for.
  needsYou,

  /// The saved credentials were refused.
  loginRejected,

  /// It did not answer.
  unreachable,
}

/// The newest result for one server: [snapshot] when it could be reached.
class OverviewEntry {
  const OverviewEntry(this.server, {this.snapshot, this.problem});

  final ServerInstance server;
  final ServerSnapshot? snapshot;
  final OverviewProblem? problem;

  /// Neither looked at nor failed yet.
  bool get loading => snapshot == null && problem == null;
}

/// Looks at several servers side by side for the all-servers overview.
///
/// A session is kept per server while the overview is open, so a refresh is
/// three calls and not a new sign-in. A call that fails drops the session, and
/// the next refresh signs in again. Like the background check it cannot ask
/// the user anything: a server that needs a certificate trust or a 2FA code is
/// reported as such.
class ServerOverviewLoader {
  ServerOverviewLoader({
    Future<TrueNasSession> Function(ServerInstance)? connect,
    this.timeout = const Duration(seconds: 20),
  }) : _connect = connect ?? connectQuietly;

  final Future<TrueNasSession> Function(ServerInstance) _connect;

  /// How long one server may take before it counts as unreachable.
  final Duration timeout;

  final _sessions = <String, TrueNasSession>{};

  /// Looks at every server in [servers] and calls [onEntry] as each answers.
  /// Sessions of servers no longer in the list are closed.
  Future<void> refresh(
    List<ServerInstance> servers,
    void Function(OverviewEntry entry) onEntry,
  ) async {
    final ids = {for (final server in servers) server.id};
    for (final id in _sessions.keys.where((id) => !ids.contains(id)).toList()) {
      unawaited(_drop(id));
    }
    await Future.wait([
      for (final server in servers) _look(server).then(onEntry),
    ]);
  }

  Future<OverviewEntry> _look(ServerInstance server) async {
    try {
      final session = _sessions[server.id] ??= await _connect(server)
          .timeout(timeout);
      final (pools, alerts, jobs) = await (
        session.pools(),
        session.alerts(),
        session.activeJobs(),
      ).wait.timeout(timeout);
      return OverviewEntry(
        server,
        snapshot: ServerSnapshot(
          pools: pools,
          alerts: [
            for (final alert in alerts)
              if (!alert.dismissed) alert,
          ]..sort((a, b) => b.level.index.compareTo(a.level.index)),
          jobs: jobs,
        ),
      );
    } catch (error) {
      await _drop(server.id);
      final problem = switch (error) {
        ConnectCancelled() => OverviewProblem.needsYou,
        LoginRejected() => OverviewProblem.loginRejected,
        _ => OverviewProblem.unreachable,
      };
      if (problem == OverviewProblem.unreachable) {
        AppLog.instance.warning(
          'overview',
          'Look at "${server.name}" failed: '
              '${error is ApiException ? error.message : error}',
        );
      }
      return OverviewEntry(server, problem: problem);
    }
  }

  Future<void> _drop(String id) async {
    final session = _sessions.remove(id);
    try {
      await session?.close();
    } catch (_) {}
  }

  Future<void> close() async {
    for (final id in _sessions.keys.toList()) {
      await _drop(id);
    }
  }
}
