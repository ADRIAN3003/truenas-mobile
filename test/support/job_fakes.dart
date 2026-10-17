import 'dart:async';

import 'package:truenas_mobile/core/api/events.dart';
import 'package:truenas_mobile/core/jobs/job_tracker.dart';
import 'package:truenas_mobile/core/jobs/live_progress.dart';
import 'package:truenas_mobile/core/models/job.dart';

/// Builds a `core.get_jobs` row.
Map<String, dynamic> jobJson(
  int id,
  String method, {
  String state = 'RUNNING',
  num? percent,
  String text = '',
  List<Object?>? arguments,
  String? error,
}) => {
  'id': id,
  'method': method,
  'state': state,
  'progress': {'percent': percent, 'description': text},
  'arguments': arguments ?? [],
  'abortable': true,
  'error': error,
  'time_started': {r'$date': 1760000000000},
};

/// The jobs of a server, without a server.
class FakeJobSource implements JobSource {
  final active = <Map<String, dynamic>>[];
  final finished = <int, Map<String, dynamic>>{};
  final _changes = StreamController<CollectionUpdate>.broadcast();
  final _reconnected = StreamController<void>.broadcast();

  /// While set, every question fails, like a server that cannot be reached.
  var offline = false;
  var activeCalls = 0;

  @override
  Future<List<TrueNasJob>> activeJobs() async {
    activeCalls++;
    if (offline) throw StateError('offline');
    return [for (final j in active) TrueNasJob.fromJson(j)];
  }

  @override
  Future<List<TrueNasJob>> jobsById(Iterable<int> ids) async {
    if (offline) throw StateError('offline');
    return [
      for (final id in ids)
        if (finished[id] != null) TrueNasJob.fromJson(finished[id]!),
    ];
  }

  @override
  Stream<CollectionUpdate> changes() => _changes.stream;

  @override
  Stream<void> get reconnected => _reconnected.stream;

  /// Sends an event and keeps the job list in step with it, as a server does.
  void emit(String msg, int id, Map<String, dynamic> fields) {
    final index = active.indexWhere((j) => j['id'] == id);
    if (index != -1) {
      active[index] = {...active[index], ...fields};
      final state = active[index]['state'];
      if (state != 'RUNNING' && state != 'WAITING') {
        finished[id] = active.removeAt(index);
      }
    }
    _send(msg, id, fields);
  }

  void _send(String msg, int id, Map<String, dynamic> fields) => _changes.add(
    CollectionUpdate(
      msg: msg,
      collection: 'core.get_jobs',
      id: id,
      fields: fields,
    ),
  );

  void reconnect() => _reconnected.add(null);
}

/// The lock screen, without a phone.
class FakeLiveProgress implements LiveProgress {
  FakeLiveProgress({this.supported = true, this.liveSupport = LiveSupport.ok});

  final bool supported;
  final LiveSupport liveSupport;
  final shown = <LiveProgressUpdate>[];
  final ended = <String>[];
  final keptOnReconcile = <Set<String>>[];
  var permissionAsked = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<LiveSupport> support() async => liveSupport;

  @override
  Future<bool> requestPermission() async {
    permissionAsked++;
    return true;
  }

  @override
  Future<void> show(LiveProgressUpdate update) async => shown.add(update);

  @override
  Future<void> end(String id) async => ended.add(id);

  @override
  Future<void> endAllExcept(Set<String> keep) async =>
      keptOnReconcile.add(keep);
}
