import 'api_exception.dart';
import '../models/json.dart';
import '../models/storage.dart';
import 'method_catalog.dart';
import 'json_rpc_client.dart';

/// Pools, datasets, snapshots and disks.
class StorageApi {
  StorageApi(this._client, this._catalog);

  final JsonRpcClient _client;
  final MethodCatalog _catalog;
  String? _snapshotService;

  Future<List<PoolDetail>> pools() async {
    final result = await _client.call('pool.query') as List<dynamic>;
    return result.map((e) => PoolDetail.fromJson(asMap(e))).toList();
  }

  Future<PoolDetail> pool(int id) async {
    final result = await _client.call('pool.query', [
      [
        ['id', '=', id],
      ],
    ]) as List<dynamic>;
    return PoolDetail.fromJson(asMap(result.single));
  }

  /// Starts, pauses or stops a scrub. Returns the job id.
  /// `pool.scrub.scrub` exists in every supported release (deprecated, but
  /// still served, in 27).
  Future<int> scrub(String pool, ScrubAction action) async => asInt(
    await _client.call('pool.scrub.scrub', [pool, action.name.toUpperCase()]),
  );

  /// All datasets of [pool], parents before children.
  Future<List<Dataset>> datasets(String pool) async {
    final result = await _client.call('pool.dataset.query', [
      [
        ['pool', '=', pool],
      ],
      {
        'extra': {'flat': true},
        'order_by': ['name'],
      },
    ]) as List<dynamic>;
    return result.map((e) => Dataset.fromJson(asMap(e))).toList();
  }

  Future<void> createDataset(String name) =>
      _client.call('pool.dataset.create', [
        {'name': name, 'type': 'FILESYSTEM'},
      ]);

  Future<void> createVolume(String name, int sizeBytes) =>
      _client.call('pool.dataset.create', [
        {'name': name, 'type': 'VOLUME', 'volsize': sizeBytes, 'sparse': true},
      ]);

  Future<void> deleteDataset(String id) => _client.call('pool.dataset.delete', [
    id,
    {'recursive': true},
  ]);

  /// `pool.snapshot` on 25.10 and newer, `zfs.snapshot` on 25.04.
  Future<String> _snapshots() async => _snapshotService ??=
      await _catalog.firstWith(['pool.snapshot', 'zfs.snapshot'], 'query') ??
      'pool.snapshot';

  /// Snapshots of [dataset], newest first.
  Future<List<Snapshot>> snapshots(String dataset) async {
    final result = await _client.call('${await _snapshots()}.query', [
      [
        ['dataset', '=', dataset],
      ],
    ]) as List<dynamic>;
    final snapshots = result.map((e) => Snapshot.fromJson(asMap(e))).toList()
      ..sort(
        (a, b) =>
            (b.created ?? DateTime(0)).compareTo(a.created ?? DateTime(0)),
      );
    return snapshots;
  }

  Future<void> createSnapshot(
    String dataset,
    String name, {
    bool recursive = false,
  }) async => _client.call('${await _snapshots()}.create', [
    {'dataset': dataset, 'name': name, 'recursive': recursive},
  ]);

  Future<void> deleteSnapshot(String id) async =>
      _client.call('${await _snapshots()}.delete', [id]);

  /// Rolls the dataset back to snapshot [id]. With [destroyNewer], newer
  /// snapshots are destroyed (ZFS refuses the rollback otherwise);
  /// [destroyClones] also destroys clones of those, and [force] unmounts
  /// what is in the way.
  Future<void> rollbackSnapshot(
    String id, {
    bool destroyNewer = false,
    bool destroyClones = false,
    bool force = false,
  }) async => _client.call('${await _snapshots()}.rollback', [
    id,
    {
      'recursive': destroyNewer,
      if (destroyClones) 'recursive_clones': true,
      if (force) 'force': true,
    },
  ]);

  /// Whether the server can clone snapshots.
  Future<bool> canCloneSnapshots() async =>
      _catalog.has('${await _snapshots()}.clone');

  /// Makes the new dataset [target] (`pool/path`) from snapshot [id].
  Future<void> cloneSnapshot(String id, String target) async =>
      _client.call('${await _snapshots()}.clone', [
        {'snapshot': id, 'dataset_dst': target},
      ]);

  /// All disks with their pool and, where available, temperature.
  Future<List<Disk>> disks() async {
    final result = await _client.call('disk.query', [
      [],
      {
        'extra': {'pools': true},
        'order_by': ['name'],
      },
    ]) as List<dynamic>;
    final disks = result.map((e) => Disk.fromJson(asMap(e))).toList();
    final temperatures = await diskTemperatures();
    return [
      for (final disk in disks) disk.withTemperature(temperatures[disk.name]),
    ];
  }

  /// Degrees Celsius per disk name; empty when the server cannot say.
  Future<Map<String, double>> diskTemperatures() async {
    try {
      final result = asMap(await _client.call('disk.temperatures'));
      return {
        for (final entry in result.entries)
          if (entry.value is num) entry.key: (entry.value as num).toDouble(),
      };
    } catch (_) {
      return const {};
    }
  }

  /// Whether the server can list the self-test log (`smart.test.results`).
  Future<bool> canReadSmart() async => _catalog.has('smart.test.results');

  /// Whether the server can start self-tests (`smart.test.manual_test`).
  Future<bool> canRunSmartTests() async =>
      _catalog.has('smart.test.manual_test');

  /// The self-test log of [disk], newest test first.
  Future<SmartResults> smartResults(Disk disk) async {
    final result = await _client.call('smart.test.results', [
      [
        ['disk', '=', disk.name],
      ],
    ]) as List<dynamic>;
    return result.isEmpty
        ? SmartResults.none
        : SmartResults.fromJson(asMap(result.first));
  }

  /// Starts a self-test of [type] on [disk]. The test runs on the disk, not
  /// as a job, so progress is read back with [smartResults].
  Future<void> runSmartTest(Disk disk, SmartTestType type) async {
    final result = await _client.call('smart.test.manual_test', [
      [
        {'identifier': disk.identifier ?? disk.name, 'type': type.apiName},
      ],
    ]) as List<dynamic>;
    for (final entry in result) {
      final error = asMap(entry)['error'];
      if (error is String && error.isNotEmpty) throw ApiException(error);
    }
  }
}

enum ScrubAction { start, pause, stop }
