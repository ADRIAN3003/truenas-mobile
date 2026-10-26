import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/api/api_exception.dart';
import 'package:truenas_mobile/core/api/storage_api.dart';
import 'package:truenas_mobile/core/models/storage.dart';
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

  test('smart results are parsed newest first with progress', () async {
    await connect();
    server.smartProgress = 40;
    final disk = (await session.storage.disks()).first;
    final results = await session.storage.smartResults(disk);
    expect(results.tests.map((t) => t.number), [1, 2]);
    expect(results.tests.first.passed, isTrue);
    expect(results.tests.last.failed, isTrue);
    expect(results.tests.last.lbaOfFirstError, 4096);
    expect(results.progress, 40);
    expect(results.running, isTrue);
    expect(results.lastFinished?.description, 'Short offline');
    expect(server.calls.last.$2, [
      [
        ['disk', '=', 'sda'],
      ],
    ]);
  });

  test('smart attributes give hours and sector counts', () async {
    await connect();
    final disk = (await session.storage.disks()).first;
    expect(await session.storage.canReadSmartAttributes(), isTrue);
    final attributes = await session.storage.smartAttributes(disk);
    expect(attributes.powerOnHours, 12345);
    expect(attributes.reallocatedSectors, 0);
    expect(attributes.pendingSectors, 0);
    expect(attributes.sectorsBad, isFalse);
    expect(server.calls.last.$1, 'disk.smart_attributes');
    expect(server.calls.last.$2, ['sda']);
  });

  test('attribute raw values with extra text keep the leading number', () {
    final attributes = SmartAttributes.fromJson([
      {
        'id': 9,
        'name': 'Power_On_Hours',
        'raw': {'value': 4294967296, 'string': '12345h+12m+3.000s'},
      },
      {'id': 5, 'raw': 7},
      {'id': 197, 'raw': '3 (0 0 0)'},
    ]);
    expect(attributes.powerOnHours, 12345);
    expect(attributes.reallocatedSectors, 7);
    expect(attributes.pendingSectors, 3);
    expect(attributes.sectorsBad, isTrue);
  });

  test(
    'a disk without attributes, or a server without them, gives none',
    () async {
      await connect();
      final disk = (await session.storage.disks()).last;
      expect((await session.storage.smartAttributes(disk)).isEmpty, isTrue);
      expect(SmartAttributes.fromJson('nonsense').isEmpty, isTrue);
    },
  );

  test('attribute support follows the method catalog', () async {
    await connect();
    server.smartAttributes = false;
    expect(await session.storage.canReadSmartAttributes(), isFalse);
  });

  test('health is critical when the newest finished test failed', () {
    final results = SmartResults.fromJson({
      'tests': [
        {'num': 1, 'status': 'FAILED'},
        {'num': 2, 'status': 'SUCCESS'},
      ],
    });
    expect(smartHealth(results, null), SmartHealth.critical);
  });

  test('health is a warning for an older failure or bad sectors', () {
    final older = SmartResults.fromJson({
      'tests': [
        {'num': 1, 'status': 'SUCCESS'},
        {'num': 2, 'status': 'FAILED'},
      ],
    });
    expect(smartHealth(older, null), SmartHealth.warning);
    final passed = SmartResults.fromJson({
      'tests': [
        {'num': 1, 'status': 'SUCCESS'},
      ],
    });
    expect(smartHealth(passed, null), SmartHealth.good);
    final bad = SmartAttributes.fromJson([
      {'id': 5, 'raw': 12},
    ]);
    expect(smartHealth(passed, bad), SmartHealth.warning);
    final failing = SmartAttributes.fromJson([
      {'id': 1, 'when_failed': 'FAILING_NOW', 'raw': 0},
    ]);
    expect(smartHealth(passed, failing), SmartHealth.critical);
    final past = SmartAttributes.fromJson([
      {'id': 1, 'when_failed': 'In_the_past', 'raw': 0},
    ]);
    expect(smartHealth(null, past), SmartHealth.warning);
  });

  test('health is unknown with no tests and no attributes', () {
    expect(smartHealth(SmartResults.none, SmartAttributes.none), isNull);
    expect(smartHealth(null, null), isNull);
  });

  test('a disk without a log has no results', () async {
    await connect();
    final disk = (await session.storage.disks()).last;
    final results = await session.storage.smartResults(disk);
    expect(results.tests, isEmpty);
    expect(results.running, isFalse);
    expect(results.lastFinished, isNull);
  });

  test('a self-test is started with the disk identifier and type', () async {
    await connect();
    final disk = (await session.storage.disks()).first;
    await session.storage.runSmartTest(disk, SmartTestType.long);
    expect(server.calls.last.$1, 'smart.test.manual_test');
    expect(server.calls.last.$2, [
      [
        {'identifier': '{serial}S1', 'type': 'LONG'},
      ],
    ]);
  });

  test('a rejected self-test throws the server reason', () async {
    await connect();
    server.smartRejection = 'Disk is busy';
    final disk = (await session.storage.disks()).first;
    await expectLater(
      session.storage.runSmartTest(disk, SmartTestType.short),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', 'Disk is busy'),
      ),
    );
  });

  test('smart support follows the method catalog', () async {
    await connect();
    expect(await session.storage.canReadSmart(), isTrue);
    expect(await session.storage.canRunSmartTests(), isTrue);
  });

  test('smart support is off when the server lacks the methods', () async {
    await connect();
    server.smart = false;
    expect(await session.storage.canReadSmart(), isFalse);
    expect(await session.storage.canRunSmartTests(), isFalse);
  });
}
