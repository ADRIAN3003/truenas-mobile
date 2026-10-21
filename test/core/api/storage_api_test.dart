import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/api/storage_api.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';

import '../../support/fake_truenas_server.dart';

void main() {
  late FakeTrueNasServer server;
  late TrueNasSession session;

  Future<void> connect({
    String snapshotService = 'pool.snapshot',
    bool clone = true,
  }) async {
    server = await FakeTrueNasServer.start();
    server.snapshotService = snapshotService;
    server.snapshotClone = clone;
    final (s, _) = await connectToInstance(
      ServerInstance(
        id: '1',
        name: 'Home',
        url: 'http://127.0.0.1:${server.port}',
        authMethod: AuthMethod.password,
        username: 'truenas_admin',
        secret: 'secret',
      ),
      confirmCertificate: (_) async => false,
      askOtp: () async => null,
    );
    session = s;
  }

  tearDown(() async {
    await session.close();
    await server.close();
  });

  test('pool detail parses topology and scan', () async {
    await connect();
    final pool = await session.storage.pool(1);
    expect(pool.name, 'tank');
    expect(pool.usedFraction, 0.25);
    expect(pool.scan?.state, 'FINISHED');
    expect(pool.topology.keys, ['data']);
    final mirror = pool.topology['data']!.single;
    expect(mirror.type, 'MIRROR');
    expect(mirror.children.map((d) => d.disk), ['sda', 'sdb']);
    expect(mirror.children.last.errors, 3);
  });

  test('scrub sends the action in upper case', () async {
    await connect();
    final job = await session.storage.scrub('tank', ScrubAction.pause);
    expect(job, 12);
    expect(server.calls.last.$1, 'pool.scrub.scrub');
    expect(server.calls.last.$2, ['tank', 'PAUSE']);
  });

  test('datasets can be listed, created and deleted', () async {
    await connect();
    final datasets = await session.storage.datasets('tank');
    expect(datasets.map((d) => d.id), ['tank', 'tank/media', 'tank/vm']);
    expect(datasets[1].depth, 1);
    expect(datasets[1].compressRatio, '1.50x');
    expect(datasets[2].isVolume, isTrue);
    expect(datasets[2].volsize, 1073741824);

    await session.storage.createVolume('tank/vm2', 2 * 1073741824);
    expect(server.calls.last.$2.first, {
      'name': 'tank/vm2',
      'type': 'VOLUME',
      'volsize': 2147483648,
      'sparse': true,
    });

    await session.storage.deleteDataset('tank/media');
    expect(server.calls.last.$2, [
      'tank/media',
      {'recursive': true},
    ]);
    expect((await session.storage.datasets('tank')).map((d) => d.id), [
      'tank',
      'tank/vm',
      'tank/vm2',
    ]);
  });

  for (final service in ['pool.snapshot', 'zfs.snapshot']) {
    test('snapshots use $service when the server offers it', () async {
      await connect(snapshotService: service);
      final snapshots = await session.storage.snapshots('tank/media');
      // Newest first.
      expect(snapshots.map((s) => s.name), ['auto-2', 'auto-1']);
      expect(snapshots.first.referenced, 4096);
      expect(snapshots.first.created, isNotNull);

      await session.storage.createSnapshot('tank/media', 'manual');
      await session.storage.rollbackSnapshot(
        'tank/media@manual',
        destroyNewer: true,
      );
      await session.storage.deleteSnapshot('tank/media@auto-1');
      expect(await session.storage.canCloneSnapshots(), isTrue);
      await session.storage.cloneSnapshot('tank/media@auto-2', 'tank/copy');
      final methods = server.calls.map((c) => c.$1).toList();
      expect(
        methods,
        containsAllInOrder([
          '$service.query',
          '$service.create',
          '$service.rollback',
          '$service.delete',
          '$service.clone',
        ]),
      );
      Object? paramsOf(String method) =>
          server.calls.firstWhere((c) => c.$1 == '$service.$method').$2;
      expect(paramsOf('delete'), ['tank/media@auto-1']);
      expect(paramsOf('rollback'), [
        'tank/media@manual',
        {'recursive': true},
      ]);
      expect(paramsOf('clone'), [
        {'snapshot': 'tank/media@auto-2', 'dataset_dst': 'tank/copy'},
      ]);
    });
  }

  test('rollback sends clone and force options only when asked', () async {
    await connect();
    await session.storage.rollbackSnapshot(
      'tank/media@auto-2',
      destroyClones: true,
      force: true,
    );
    expect(server.calls.last.$2, [
      'tank/media@auto-2',
      {'recursive': false, 'recursive_clones': true, 'force': true},
    ]);
  });

  test('clone is hidden when the server has no clone method', () async {
    await connect(clone: false);
    expect(await session.storage.canCloneSnapshots(), isFalse);
  });

  test('disks include pool and temperature', () async {
    await connect();
    final disks = await session.storage.disks();
    expect(disks.map((d) => d.name), ['sda', 'nvme0n1']);
    expect(disks.first.temperature, 34);
    expect(disks.first.pool, 'tank');
    expect(disks.last.isSsd, isTrue);
    expect(disks.last.temperature, isNull);
  });
}
