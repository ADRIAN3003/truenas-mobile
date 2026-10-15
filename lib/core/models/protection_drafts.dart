import 'json.dart';
import 'protection.dart';

/// The default snapshot naming schema, the same as new snapshot tasks use.
const defaultNamingSchema = 'auto-%Y-%m-%d_%H-%M';

/// Something to pick from in an editor: a credential or a snapshot task.
class PickOption {
  const PickOption(this.id, this.name, [this.detail = '']);

  final int id;
  final String name;
  final String detail;
}

/// Where a replication task keeps snapshots on the destination.
enum RetentionPolicy {
  source('SOURCE'),
  custom('CUSTOM'),
  none('NONE');

  const RetentionPolicy(this.value);

  final String value;

  static RetentionPolicy parse(Object? value) =>
      values.where((p) => p.value == value).firstOrNull ?? source;
}

/// The editable part of a replication task. Fields the app doesn't show
/// (exclusions, encryption, netcat ports…) are left as they are on update.
class ReplicationDraft {
  ReplicationDraft();

  factory ReplicationDraft.fromJson(Map<String, dynamic> json) {
    final push = json['direction'] != 'PULL';
    final schemas = [
      for (final s in [
        ...?(json['naming_schema'] as List<dynamic>?),
        ...?(json['also_include_naming_schema'] as List<dynamic>?),
      ])
        s.toString(),
    ];
    final regex = json['name_regex'];
    return ReplicationDraft()
      ..name = (json['name'] ?? '').toString()
      ..push = push
      ..transport = (json['transport'] ?? 'LOCAL').toString()
      ..sshCredentials = json['ssh_credentials'] is Map
          ? asInt((json['ssh_credentials'] as Map)['id'])
          : json['ssh_credentials'] as int?
      ..sourceDatasets = [
        for (final d in json['source_datasets'] as List<dynamic>? ?? [])
          d.toString(),
      ]
      ..targetDataset = (json['target_dataset'] ?? '').toString()
      ..recursive = json['recursive'] == true
      ..snapshotTasks = [
        for (final t in json['periodic_snapshot_tasks'] as List<dynamic>? ?? [])
          t is Map ? asInt(t['id']) : asInt(t),
      ]
      ..namingSchema = schemas.firstOrNull ?? defaultNamingSchema
      ..nameRegex = regex is String && regex.isNotEmpty ? regex : null
      ..auto = json['auto'] != false
      ..schedule = parseSchedule(asMap(json['schedule']))
      ..retention = RetentionPolicy.parse(json['retention_policy'])
      ..lifetimeValue = json['lifetime_value'] is num
          ? (json['lifetime_value'] as num).toInt()
          : 2
      ..lifetimeUnit =
          LifetimeUnit.values
              .where((u) => u.name.toUpperCase() == json['lifetime_unit'])
              .firstOrNull ??
          LifetimeUnit.week;
  }

  String name = '';

  /// Push from this server, or pull from a remote one.
  bool push = true;

  /// `LOCAL`, `SSH` or `SSH+NETCAT`.
  String transport = 'LOCAL';
  int? sshCredentials;
  List<String> sourceDatasets = [];
  String targetDataset = '';
  bool recursive = false;

  /// Periodic snapshot tasks whose snapshots a push sends.
  List<int> snapshotTasks = [];

  /// Which snapshots to send when no snapshot task is bound, or to pull.
  String namingSchema = defaultNamingSchema;

  /// Set on tasks made elsewhere that match snapshots by regex; kept as is.
  String? nameRegex;
  bool auto = true;

  /// A [SnapshotSchedule], cron text to keep unchanged, or null to run
  /// right after the bound snapshot task.
  Object? schedule = SnapshotSchedule.daily;
  RetentionPolicy retention = RetentionPolicy.source;
  int lifetimeValue = 2;
  LifetimeUnit lifetimeUnit = LifetimeUnit.week;

  bool get local => transport == 'LOCAL';

  /// Whether a push gets its snapshots from bound snapshot tasks.
  bool get bound => push && snapshotTasks.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'name': name,
    'direction': push ? 'PUSH' : 'PULL',
    'transport': transport,
    'ssh_credentials': local ? null : sshCredentials,
    // Options other transports reject, cleared when switching away.
    if (local) ...{'compression': null, 'speed_limit': null},
    if (transport != 'SSH+NETCAT') ...{
      'netcat_active_side': null,
      'netcat_active_side_listen_address': null,
      'netcat_active_side_port_min': null,
      'netcat_active_side_port_max': null,
      'netcat_passive_side_connect_address': null,
    },
    'source_datasets': sourceDatasets,
    'target_dataset': targetDataset,
    'recursive': recursive,
    'periodic_snapshot_tasks': push ? snapshotTasks : <int>[],
    if (nameRegex == null) ...{
      'naming_schema': push ? <String>[] : [namingSchema],
      'also_include_naming_schema': push && !bound
          ? [namingSchema]
          : <String>[],
    },
    'auto': auto,
    if (schedule is! String || !auto)
      'schedule': auto && schedule is SnapshotSchedule
          ? {
              ...(schedule as SnapshotSchedule).cron,
              'begin': '00:00',
              'end': '23:59',
            }
          : null,
    'retention_policy': retention.value,
    'lifetime_value': retention == RetentionPolicy.custom
        ? lifetimeValue
        : null,
    'lifetime_unit': retention == RetentionPolicy.custom
        ? lifetimeUnit.name.toUpperCase()
        : null,
  };
}

/// The editable part of a cloud sync task.
class CloudSyncDraft {
  CloudSyncDraft();

  factory CloudSyncDraft.fromJson(Map<String, dynamic> json) {
    final attributes = asMap(json['attributes']);
    return CloudSyncDraft()
      ..description = (json['description'] ?? '').toString()
      ..credentials = json['credentials'] is Map
          ? asInt((json['credentials'] as Map)['id'])
          : json['credentials'] as int?
      ..attributes = attributes
      ..bucket = (attributes['bucket'] ?? '').toString()
      ..folder = (attributes['folder'] ?? '').toString()
      ..path = (json['path'] ?? '').toString()
      ..push = json['direction'] != 'PULL'
      ..transferMode = (json['transfer_mode'] ?? 'COPY').toString()
      ..schedule =
          parseSchedule(asMap(json['schedule'])) ?? SnapshotSchedule.daily;
  }

  String description = '';
  int? credentials;

  /// Provider attributes as the server sent them, kept on save.
  Map<String, dynamic> attributes = const {};
  String bucket = '';
  String folder = '';
  String path = '/mnt/';
  bool push = true;

  /// `SYNC`, `COPY` or `MOVE`.
  String transferMode = 'COPY';

  /// A [SnapshotSchedule], or cron text to keep unchanged.
  Object schedule = SnapshotSchedule.daily;

  Map<String, dynamic> toJson() => {
    'description': description,
    'credentials': credentials,
    'path': path,
    'direction': push ? 'PUSH' : 'PULL',
    'transfer_mode': transferMode,
    'attributes': {
      ...Map.of(attributes)..remove('bucket'),
      if (bucket.isNotEmpty) 'bucket': bucket,
      'folder': folder,
    },
    if (schedule case final SnapshotSchedule preset) 'schedule': preset.cron,
  };
}

/// The editable part of an rsync task.
class RsyncDraft {
  RsyncDraft();

  factory RsyncDraft.fromJson(Map<String, dynamic> json) => RsyncDraft()
    ..description = (json['desc'] ?? '').toString()
    ..path = (json['path'] ?? '').toString()
    ..user = (json['user'] ?? 'root').toString()
    ..push = json['direction'] != 'PULL'
    ..ssh = json['mode'] == 'SSH'
    ..sshCredentials = json['ssh_credentials'] is Map
        ? asInt((json['ssh_credentials'] as Map)['id'])
        : json['ssh_credentials'] as int?
    ..remoteHost = (json['remotehost'] ?? '').toString()
    ..remotePort = json['remoteport'] is num
        ? (json['remoteport'] as num).toInt()
        : 22
    ..remoteModule = (json['remotemodule'] ?? '').toString()
    ..remotePath = (json['remotepath'] ?? '').toString()
    ..delete = json['delete'] == true
    ..schedule =
        parseSchedule(asMap(json['schedule'])) ?? SnapshotSchedule.daily;

  String description = '';
  String path = '/mnt/';

  /// The local user rsync runs as.
  String user = 'root';
  bool push = true;

  /// Over SSH, or to an rsync daemon module.
  bool ssh = true;

  /// A keychain SSH connection; null to use [remoteHost] and the user's
  /// own SSH key.
  int? sshCredentials;
  String remoteHost = '';
  int remotePort = 22;
  String remoteModule = '';
  String remotePath = '';

  /// Delete files on the destination that are gone from the source.
  bool delete = false;

  /// A [SnapshotSchedule], or cron text to keep unchanged.
  Object schedule = SnapshotSchedule.daily;

  Map<String, dynamic> toJson() {
    final viaKeychain = ssh && sshCredentials != null;
    return {
      'desc': description,
      'path': path,
      'user': user,
      'direction': push ? 'PUSH' : 'PULL',
      'mode': ssh ? 'SSH' : 'MODULE',
      'ssh_credentials': viaKeychain ? sshCredentials : null,
      'remotehost': viaKeychain ? null : remoteHost,
      'remoteport': ssh && !viaKeychain ? remotePort : null,
      'remotemodule': ssh ? null : remoteModule,
      'remotepath': remotePath,
      'delete': delete,
      if (schedule case final SnapshotSchedule preset) 'schedule': preset.cron,
    };
  }
}

/// The editable part of a TrueCloud backup task.
class CloudBackupDraft {
  CloudBackupDraft();

  factory CloudBackupDraft.fromJson(Map<String, dynamic> json) {
    final attributes = asMap(json['attributes']);
    return CloudBackupDraft()
      ..description = (json['description'] ?? '').toString()
      ..credentials = json['credentials'] is Map
          ? asInt((json['credentials'] as Map)['id'])
          : json['credentials'] as int?
      ..attributes = attributes
      ..bucket = (attributes['bucket'] ?? '').toString()
      ..folder = (attributes['folder'] ?? '').toString()
      ..path = (json['path'] ?? '').toString()
      ..keepLast = json['keep_last'] is num
          ? (json['keep_last'] as num).toInt()
          : 14
      ..schedule =
          parseSchedule(asMap(json['schedule'])) ?? SnapshotSchedule.daily;
  }

  String description = '';
  int? credentials;
  Map<String, dynamic> attributes = const {};
  String bucket = '';
  String folder = '';
  String path = '/mnt/';

  /// The repository password; empty keeps the current one when editing.
  String password = '';

  /// How many backups to keep.
  int keepLast = 14;
  Object schedule = SnapshotSchedule.daily;

  Map<String, dynamic> toJson() => {
    'description': description,
    'credentials': credentials,
    'path': path,
    'attributes': {
      ...Map.of(attributes)..remove('bucket'),
      if (bucket.isNotEmpty) 'bucket': bucket,
      'folder': folder,
    },
    'keep_last': keepLast,
    if (password.isNotEmpty) 'password': password,
    if (schedule case final SnapshotSchedule preset) 'schedule': preset.cron,
  };
}
