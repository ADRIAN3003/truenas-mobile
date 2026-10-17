import 'dart:async';

import '../api/events.dart';
import '../models/job.dart';
import '../session/truenas_session.dart';
import 'tracked_job.dart';

/// Where the tracker gets its jobs from: a server, or a fake in tests.
abstract interface class JobSource {
  /// The jobs that are waiting or running now.
  Future<List<TrueNasJob>> activeJobs();

  /// Jobs by id, finished or not.
  Future<List<TrueNasJob>> jobsById(Iterable<int> ids);

  /// Job additions and progress updates.
  Stream<CollectionUpdate> changes();

  /// Fires after the connection was replaced.
  Stream<void> get reconnected;
}

class SessionJobSource implements JobSource {
  const SessionJobSource(this._session);

  final TrueNasSession _session;

  @override
  Future<List<TrueNasJob>> activeJobs() => _session.activeJobs();

  @override
  Future<List<TrueNasJob>> jobsById(Iterable<int> ids) =>
      _session.jobsById(ids);

  @override
  Stream<CollectionUpdate> changes() => _session.jobChanges();

  @override
  Stream<void> get reconnected => _session.reconnected;
}

/// The tracked jobs at one moment.
class JobsSnapshot {
  const JobsSnapshot(this.jobs, {required this.connected});

  static const empty = JobsSnapshot([], connected: true);

  /// Oldest first. Finished jobs stay in the list for a few seconds.
  final List<TrackedJob> jobs;

  /// False while the server cannot be reached, so the numbers are old.
  final bool connected;

  bool get hasActive => jobs.any((t) => t.job.state.isActive);
}

/// Follows the scrubs, replications and updates of one server: from the job
/// events while the connection lives, and by asking now and then while one
/// runs, which also reconnects a socket the phone dropped.
class JobTracker {
  JobTracker(
    this._source, {
    this.pollInterval = const Duration(seconds: 15),
    this.linger = const Duration(seconds: 12),
  });

  final JobSource _source;
  final Duration pollInterval;

  /// How long a finished job stays in the snapshots.
  final Duration linger;

  final _snapshots = StreamController<JobsSnapshot>.broadcast();
  final _jobs = <int, TrackedJob>{};
  final _lingering = <int, Timer>{};

  /// Jobs the app does not follow, so their events can be skipped.
  final _ignored = <int>{};
  final _unknown = <int>{};
  StreamSubscription<CollectionUpdate>? _changes;
  StreamSubscription<void>? _reconnects;
  Timer? _poll;
  Future<void>? _refreshing;
  var _connected = true;
  var _started = false;
  var _disposed = false;

  Stream<JobsSnapshot> get snapshots => _snapshots.stream;

  JobsSnapshot get snapshot {
    final jobs = _jobs.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return JobsSnapshot(jobs, connected: _connected);
  }

  void start() {
    if (_started) return;
    _started = true;
    _changes = _source.changes().listen(_onUpdate, onError: (_) {});
    _reconnects = _source.reconnected.listen((_) => refresh());
    _poll = Timer.periodic(pollInterval, (_) {
      // Nothing to keep fresh, and no reason to wake a dropped socket.
      if (_jobs.values.any((t) => t.job.state.isActive)) refresh();
    });
    refresh();
  }

  /// Looks the jobs up again. Calls made while one is running share it.
  Future<void> refresh() {
    if (_disposed) return Future.value();
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _refresh() async {
    try {
      final active = await _source.activeJobs();
      final seen = <int>{};
      for (final job in active) {
        seen.add(job.id);
        final tracked = TrackedJob.of(job);
        if (tracked == null) {
          _ignored.add(job.id);
        } else {
          _jobs[job.id] = tracked;
        }
      }
      // Jobs that were running and are not any more: take their last state.
      final gone = [
        for (final t in _jobs.values)
          if (t.job.state.isActive && !seen.contains(t.id)) t.id,
      ];
      if (gone.isNotEmpty) {
        final finished = await _source.jobsById(gone);
        final found = <int>{};
        for (final job in finished) {
          found.add(job.id);
          _jobs[job.id] = _jobs[job.id]!.withJob(job);
        }
        for (final id in gone) {
          if (!found.contains(id)) _jobs.remove(id);
        }
      }
      _ignored.addAll(_unknown);
      _unknown.clear();
      _connected = true;
      _settleFinished();
    } catch (_) {
      _connected = false;
    }
    _emit();
  }

  void _onUpdate(CollectionUpdate update) {
    final fields = update.fields;
    final id = _asId(update.id ?? fields?['id']);
    if (id == null) return;
    if (update.msg == 'removed') {
      if (_jobs.remove(id) != null) _emit();
      return;
    }
    if (fields == null || _ignored.contains(id)) return;
    final known = _jobs[id];
    if (known != null) {
      _jobs[id] = known.withJob(known.job.merge(fields));
      _settleFinished();
      _emit();
    } else if (fields.containsKey('method')) {
      final tracked = TrackedJob.of(TrueNasJob.fromJson({'id': id, ...fields}));
      if (tracked == null) {
        _ignored.add(id);
        return;
      }
      _jobs[id] = tracked;
      _settleFinished();
      _emit();
    } else {
      // A change to a job whose start was missed (a dropped connection).
      _unknown.add(id);
      refresh();
    }
  }

  static int? _asId(Object? id) => id is num ? id.toInt() : null;

  /// Drops each finished job a while after it finished.
  void _settleFinished() {
    for (final t in _jobs.values) {
      if (t.job.state.isActive || _lingering.containsKey(t.id)) continue;
      _lingering[t.id] = Timer(linger, () {
        _lingering.remove(t.id);
        _jobs.remove(t.id);
        _emit();
      });
    }
  }

  void _emit() {
    if (!_disposed) _snapshots.add(snapshot);
  }

  Future<void> dispose() async {
    _disposed = true;
    _poll?.cancel();
    for (final timer in _lingering.values) {
      timer.cancel();
    }
    await _changes?.cancel();
    await _reconnects?.cancel();
    await _snapshots.close();
  }
}
