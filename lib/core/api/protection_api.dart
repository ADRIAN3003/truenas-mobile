import '../models/json.dart';
import '../models/protection.dart';
import '../models/protection_drafts.dart';
import 'json_rpc_client.dart';
import 'method_catalog.dart';

/// Periodic snapshots, replication, cloud sync, TrueCloud backup and rsync
/// tasks. Kinds the server doesn't offer are left out.
class ProtectionApi {
  ProtectionApi(this._client, this._catalog);

  final JsonRpcClient _client;
  final MethodCatalog _catalog;

  /// Which task kinds this server has.
  Future<List<ProtectionKind>> availableKinds() async => [
    for (final kind in ProtectionKind.values)
      if (await _catalog.has('${kind.service}.query')) kind,
  ];

  Future<List<ProtectionTask>> tasks(ProtectionKind kind) async {
    final result = await _client.call('${kind.service}.query') as List<dynamic>;
    return [for (final e in result) ProtectionTask.fromJson(kind, asMap(e))]
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Every available kind with its tasks.
  Future<Map<ProtectionKind, List<ProtectionTask>>> allTasks() async {
    final kinds = await availableKinds();
    final lists = await Future.wait(kinds.map(tasks));
    return {for (final (i, kind) in kinds.indexed) kind: lists[i]};
  }

  Future<void> setEnabled(ProtectionTask task, bool enabled) =>
      _client.call('${task.kind.service}.update', [
        task.id,
        {'enabled': enabled},
      ]);

  /// Starts the task now. Long transfers keep running in the background
  /// and show up under Jobs.
  Future<void> runNow(ProtectionTask task) =>
      _client.call(task.kind.runMethod, [task.id]);

  /// Stops a running cloud sync or cloud backup.
  Future<void> abort(ProtectionTask task) =>
      _client.call('${task.kind.service}.abort', [task.id]);

  Future<void> createSnapshotTask({
    required String dataset,
    required bool recursive,
    required int lifetimeValue,
    required LifetimeUnit lifetimeUnit,
    required SnapshotSchedule schedule,
  }) => _client.call('pool.snapshottask.create', [
    {
      'dataset': dataset,
      'recursive': recursive,
      'lifetime_value': lifetimeValue,
      'lifetime_unit': lifetimeUnit.name.toUpperCase(),
      'naming_schema': 'auto-%Y-%m-%d_%H-%M',
      'schedule': {...schedule.cron, 'begin': '00:00', 'end': '23:59'},
      'enabled': true,
    },
  ]);

  /// SSH connections from the keychain, for remote replication.
  Future<List<PickOption>> sshCredentials() async {
    final result = await _client.call('keychaincredential.query', [
      [
        ['type', '=', 'SSH_CREDENTIALS'],
      ],
    ]) as List<dynamic>;
    return [
      for (final e in result.map(asMap))
        PickOption(asInt(e['id']), (e['name'] ?? '').toString()),
    ];
  }

  /// Cloud credentials (S3, B2, Dropbox…), for cloud sync tasks.
  Future<List<PickOption>> cloudCredentials() async {
    final result =
        await _client.call('cloudsync.credentials.query') as List<dynamic>;
    return [
      for (final e in result.map(asMap))
        PickOption(
          asInt(e['id']),
          (e['name'] ?? '').toString(),
          switch (e['provider']) {
            final Map<String, dynamic> p => (p['type'] ?? '').toString(),
            final Object p => p.toString(),
            null => '',
          },
        ),
    ];
  }

  /// Creates a replication task, or updates the one with [id].
  Future<void> saveReplication(ReplicationDraft draft, {int? id}) =>
      _save('replication', draft.toJson(), id);

  /// Creates a cloud sync task, or updates the one with [id].
  Future<void> saveCloudSync(CloudSyncDraft draft, {int? id}) =>
      _save('cloudsync', draft.toJson(), id);

  Future<void> _save(String service, Map<String, dynamic> data, int? id) =>
      id == null
      ? _client.call('$service.create', [data])
      : _client.call('$service.update', [id, data]);

  /// Deletes a task. Snapshots it already took are kept.
  Future<void> delete(ProtectionTask task) =>
      _client.call('${task.kind.service}.delete', [task.id]);
}
