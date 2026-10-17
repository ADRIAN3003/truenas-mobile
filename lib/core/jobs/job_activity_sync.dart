import 'dart:async';

import '../models/job.dart';
import 'job_tracker.dart';
import 'live_progress.dart';
import 'tracked_job.dart';

/// The words on the lock screen, in the app's language.
class JobTexts {
  const JobTexts({
    required this.kind,
    required this.waiting,
    required this.running,
    required this.done,
    required this.failed,
    required this.aborted,
    required this.stale,
    required this.channelName,
    required this.channelDescription,
  });

  final String Function(JobKind kind) kind;
  final String waiting;
  final String running;
  final String done;
  final String failed;
  final String aborted;

  /// Shown when the app has stopped getting news of the job.
  final String stale;
  final String channelName;
  final String channelDescription;
}

/// Mirrors the tracked jobs of one server on the lock screen.
///
/// It sends an update when a job's state, text or whole percent changes, at
/// most once in [minGap] for each job, and again every [heartbeat] while the
/// job runs, so the phone knows the app is still looking. When the server
/// cannot be reached the activities say so instead of showing old progress.
class JobActivitySync {
  JobActivitySync({
    required this._progress,
    required this._tracker,
    required this._serverName,
    required this._texts,
    this.idPrefix = '',
    this._enabled = true,
    this.minGap = const Duration(seconds: 2),
    this.heartbeat = const Duration(seconds: 30),
  });

  final LiveProgress _progress;
  final JobTracker _tracker;
  final String Function() _serverName;
  final JobTexts Function() _texts;

  /// Keeps the ids of different servers apart.
  final String idPrefix;
  final Duration minGap;
  final Duration heartbeat;

  bool _enabled;
  final _sent = <String, _Sent>{};
  final _latest = <String, LiveProgressUpdate>{};
  final _queued = <String, LiveProgressUpdate>{};
  StreamSubscription<JobsSnapshot>? _subscription;
  Timer? _heartbeat;
  Timer? _flush;
  bool? _supported;
  var _reconciled = false;
  var _askedPermission = false;
  var _disposed = false;

  void start() {
    _subscription = _tracker.snapshots.listen(_onSnapshot);
    _heartbeat = Timer.periodic(heartbeat, (_) => _beat());
  }

  /// Turning it off removes what is on the lock screen.
  Future<void> setEnabled(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    if (value) {
      _onSnapshot(_tracker.snapshot);
    } else {
      await _clear();
    }
  }

  Future<bool> _isSupported() async =>
      _supported ??= await _progress.isSupported();

  Future<void> _onSnapshot(JobsSnapshot snapshot) async {
    if (!_enabled || _disposed || !await _isSupported()) return;
    final texts = _texts();
    final ids = <String>{};
    for (final tracked in snapshot.jobs) {
      final id = '$idPrefix${tracked.id}';
      ids.add(id);
      final update = _build(id, tracked, snapshot.connected, texts);
      _latest[id] = update;
      _push(update);
    }
    if (!_reconciled) {
      _reconciled = true;
      // Whatever an earlier run left behind is not being followed any more.
      await _progress.endAllExcept(ids);
    }
    // A job that vanished while running (deleted, or never seen finish).
    for (final id in [..._sent.keys]) {
      if (ids.contains(id)) continue;
      final last = _latest.remove(id);
      _sent.remove(id);
      _queued.remove(id);
      if (last != null && !last.isFinal) await _progress.end(id);
    }
    if (snapshot.hasActive && !_askedPermission) {
      _askedPermission = true;
      await _progress.requestPermission();
    }
  }

  LiveProgressUpdate _build(
    String id,
    TrackedJob tracked,
    bool connected,
    JobTexts texts,
  ) {
    final job = tracked.job;
    final lost = !connected && job.state.isActive;
    final status = lost
        ? LiveStatus.stale
        : switch (job.state) {
            JobState.waiting => LiveStatus.waiting,
            JobState.running => LiveStatus.running,
            JobState.success => LiveStatus.done,
            JobState.failed => LiveStatus.failed,
            JobState.aborted => LiveStatus.aborted,
          };
    final statusLabel = switch (status) {
      LiveStatus.waiting => texts.waiting,
      LiveStatus.running => texts.running,
      LiveStatus.done => texts.done,
      LiveStatus.failed => texts.failed,
      LiveStatus.aborted => texts.aborted,
      LiveStatus.stale => texts.stale,
    };
    final percent = job.percent;
    final progress = switch (status) {
      LiveStatus.done => 1.0,
      LiveStatus.waiting => null,
      _ => percent == null ? null : (percent / 100).clamp(0.0, 1.0),
    };
    final detail = switch (status) {
      LiveStatus.running when job.progressText.isNotEmpty => job.progressText,
      LiveStatus.failed when job.error?.isNotEmpty == true => _firstLine(
        job.error!,
      ),
      _ => statusLabel,
    };
    final title = tracked.target == null
        ? texts.kind(tracked.kind)
        : '${texts.kind(tracked.kind)} · ${tracked.target}';
    return LiveProgressUpdate(
      id: id,
      kind: tracked.kind,
      title: title,
      server: _serverName(),
      detail: detail,
      progress: progress,
      status: status,
      statusLabel: statusLabel,
      staleLabel: texts.stale,
      startedAt: job.started ?? DateTime.now(),
      channelName: texts.channelName,
      channelDescription: texts.channelDescription,
    );
  }

  static String _firstLine(String text) {
    final line = text.trim().split('\n').first;
    return line.length > 140 ? '${line.substring(0, 137)}...' : line;
  }

  void _push(LiveProgressUpdate update) {
    final last = _sent[update.id];
    final now = DateTime.now();
    final sameStatus = last != null && last.status == update.status;
    if (sameStatus && last.same(update)) return;
    if (sameStatus && now.difference(last.at) < minGap) {
      _queued[update.id] = update;
      _flush ??= Timer(minGap, _flushQueued);
      return;
    }
    _send(update);
  }

  void _flushQueued() {
    _flush = null;
    final queued = [..._queued.values];
    _queued.clear();
    queued.forEach(_push);
  }

  void _send(LiveProgressUpdate update) {
    _queued.remove(update.id);
    _sent[update.id] = _Sent(update);
    _progress.show(update);
  }

  /// Tells the phone the app is still following the jobs that run.
  void _beat() {
    if (!_enabled || _disposed || !_tracker.snapshot.connected) return;
    for (final update in _latest.values) {
      if (!update.isFinal && update.status != LiveStatus.stale) _send(update);
    }
  }

  Future<void> _clear() async {
    _flush?.cancel();
    _flush = null;
    _queued.clear();
    final ids = [..._sent.keys];
    _sent.clear();
    _latest.clear();
    for (final id in ids) {
      await _progress.end(id);
    }
    _reconciled = false;
  }

  /// Stops following. Activities of jobs still running are removed: nobody
  /// would update them any more.
  Future<void> dispose() async {
    _disposed = true;
    _heartbeat?.cancel();
    _flush?.cancel();
    await _subscription?.cancel();
    for (final entry in _latest.entries) {
      if (!entry.value.isFinal) await _progress.end(entry.key);
    }
  }
}

class _Sent {
  _Sent(LiveProgressUpdate update)
    : status = update.status,
      detail = update.detail,
      percent = update.progress == null
          ? null
          : (update.progress! * 100).floor(),
      at = DateTime.now();

  final LiveStatus status;
  final String detail;
  final int? percent;
  final DateTime at;

  bool same(LiveProgressUpdate update) =>
      detail == update.detail &&
      percent ==
          (update.progress == null ? null : (update.progress! * 100).floor());
}
