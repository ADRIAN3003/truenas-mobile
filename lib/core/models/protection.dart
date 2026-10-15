import 'json.dart';

/// The kinds of data protection task, with the API service behind each.
enum ProtectionKind {
  snapshot('pool.snapshottask'),
  replication('replication'),
  cloudSync('cloudsync'),
  cloudBackup('cloud_backup'),
  rsync('rsynctask');

  const ProtectionKind(this.service);

  /// e.g. `pool.snapshottask`.
  final String service;

  /// The method that starts the task now.
  String get runMethod => switch (this) {
    snapshot || replication || rsync => '$service.run',
    cloudSync || cloudBackup => '$service.sync',
  };

  /// Whether a running task can be stopped from the app.
  bool get abortable => this == cloudSync || this == cloudBackup;
}

/// Last known outcome of a task, normalised across the zettarepl `state`
/// objects (snapshots, replication) and last-job objects (cloud, rsync).
enum TaskStatus {
  never,
  waiting,
  running,
  success,
  failed,
  held;

  static TaskStatus parse(Object? value) =>
      switch (value?.toString().toUpperCase()) {
        'RUNNING' => running,
        'FINISHED' || 'SUCCESS' => success,
        'ERROR' || 'FAILED' || 'ABORTED' => failed,
        'WAITING' || 'PENDING' => waiting,
        'HOLD' => held,
        _ => never,
      };
}

/// One data protection task, whatever its kind.
class ProtectionTask {
  const ProtectionTask({
    required this.kind,
    required this.id,
    required this.name,
    required this.detail,
    required this.enabled,
    required this.status,
    this.lastRun,
    this.error,
    this.progress,
    this.recursive = false,
    this.lifetimeValue,
    this.lifetimeUnit,
    this.schedule,
    this.raw = const {},
  });

  factory ProtectionTask.fromJson(
    ProtectionKind kind,
    Map<String, dynamic> json,
  ) {
    final state = asMap(json['state']);
    final job = asMap(json['job']);
    final usesJob = kind.abortable || kind == ProtectionKind.rsync;
    // Replication reports a running job separately from its last state.
    final source =
        usesJob || (kind == ProtectionKind.replication && job.isNotEmpty)
        ? job
        : state;
    final progress = asMap(source['progress'])['percent'];
    final (name, detail) = switch (kind) {
      ProtectionKind.snapshot => ((json['dataset'] ?? '').toString(), ''),
      ProtectionKind.replication => (
        (json['name'] ?? '').toString(),
        '${json['direction'] ?? ''} '
            '${_strings(json['source_datasets']).join(', ')} → '
            '${json['target_dataset'] ?? ''}',
      ),
      ProtectionKind.cloudSync || ProtectionKind.cloudBackup => (
        _first(json['description'], json['path']),
        [
          if (json['direction'] != null) json['direction'].toString(),
          (json['path'] ?? '').toString(),
          if (asMap(json['credentials'])['name'] case final String c) '→ $c',
        ].join(' '),
      ),
      ProtectionKind.rsync => (
        _first(json['desc'], json['path']),
        '${json['direction'] ?? ''} ${json['path'] ?? ''} → '
            '${_rsyncRemote(json)}',
      ),
    };
    final error = source['error'];
    return ProtectionTask(
      kind: kind,
      id: asInt(json['id']),
      name: name,
      detail: detail.trim(),
      enabled: json['enabled'] != false,
      status: TaskStatus.parse(source['state']),
      lastRun:
          asDate(source['datetime']) ??
          asDate(source['time_finished']) ??
          asDate(source['time_started']),
      error: error is String && error.isNotEmpty ? error : null,
      progress: progress is num ? progress.toDouble() : null,
      recursive: json['recursive'] == true,
      lifetimeValue: json['lifetime_value'] is num
          ? (json['lifetime_value'] as num).toInt()
          : null,
      lifetimeUnit: LifetimeUnit.values
          .where((u) => u.name.toUpperCase() == json['lifetime_unit'])
          .firstOrNull,
      schedule: _schedule(asMap(json['schedule'])),
      raw: json,
    );
  }

  final ProtectionKind kind;
  final int id;
  final String name;

  /// What it protects and where to, on one line.
  final String detail;
  final bool enabled;
  final TaskStatus status;
  final DateTime? lastRun;
  final String? error;

  /// 0 to 100 while running, when reported.
  final double? progress;

  // Periodic snapshot tasks only.
  final bool recursive;
  final int? lifetimeValue;
  final LifetimeUnit? lifetimeUnit;

  /// A preset when the cron matches one, otherwise the cron text.
  final Object? schedule;

  /// The task as the server sent it, for editing.
  final Map<String, dynamic> raw;
}

/// A preset schedule for new periodic snapshot tasks.
enum SnapshotSchedule {
  hourly({'minute': '0', 'hour': '*', 'dom': '*', 'month': '*', 'dow': '*'}),
  daily({'minute': '0', 'hour': '0', 'dom': '*', 'month': '*', 'dow': '*'}),
  weekly({'minute': '0', 'hour': '0', 'dom': '*', 'month': '*', 'dow': '0'});

  const SnapshotSchedule(this.cron);

  final Map<String, String> cron;
}

/// Lifetime units accepted by `pool.snapshottask`.
enum LifetimeUnit { hour, day, week, month, year }

/// Reads a cron object as a [SnapshotSchedule] preset or cron text.
Object? parseSchedule(Map<String, dynamic> s) => _schedule(s);

Object? _schedule(Map<String, dynamic> s) {
  if (s.isEmpty) return null;
  final cron = {
    for (final key in const ['minute', 'hour', 'dom', 'month', 'dow'])
      key: (s[key] ?? '*').toString(),
  };
  for (final preset in SnapshotSchedule.values) {
    final matches = preset.cron.entries.every(
      (e) => int.tryParse(e.value) != null
          ? int.tryParse(cron[e.key]!) == int.parse(e.value)
          : cron[e.key] == e.value,
    );
    if (matches) return preset;
  }
  return cron.values.join(' ');
}

String _first(Object? a, Object? b) {
  final text = (a ?? '').toString();
  return text.isNotEmpty ? text : (b ?? '').toString();
}

List<String> _strings(Object? value) => [
  if (value is List)
    for (final v in value) v.toString(),
];

/// Where an rsync task copies to, written the way rsync itself takes it:
/// `host::module/path` for a daemon module, `host:path` over SSH.
String _rsyncRemote(Map<String, dynamic> json) {
  final path = (json['remotepath'] ?? '').toString();
  if (json['mode'] == 'MODULE') {
    final module = (json['remotemodule'] ?? '').toString();
    final sub = path.isEmpty ? '' : '/${path.replaceFirst(RegExp('^/+'), '')}';
    return '${json['remotehost'] ?? ''}::$module$sub';
  }
  final host =
      json['remotehost'] ?? asMap(json['ssh_credentials'])['name'] ?? '';
  return '$host:$path';
}
