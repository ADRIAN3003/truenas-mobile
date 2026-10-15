import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/api/sharing_api.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';

import '../../support/fake_truenas_server.dart';

void main() {
  late FakeTrueNasServer server;
  late TrueNasSession session;

  Future<void> connect({bool legacy = false}) async {
    server = await FakeTrueNasServer.start();
    server.legacy = legacy;
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

  test('services are sorted by display name', () async {
    await connect();
    final services = await session.sharing.services();
    expect(services.map((s) => s.displayName), ['NFS', 'SMB', 'SSH']);
    expect(services.first.running, isFalse);
    expect(services[1].enable, isTrue);
  });

  test('25.10+ controls services with the service.control job', () async {
    await connect();
    await session.sharing.controlService('nfs', ServiceAction.start);
    final methods = server.calls.map((c) => c.$1).toList();
    expect(methods, containsAllInOrder(['service.control', 'core.get_jobs']));
    expect(
      server.calls.firstWhere((c) => c.$1 == 'service.control').$2.take(2),
      ['START', 'nfs'],
    );
    expect(server.services[1]['state'], 'RUNNING');
  });

  test('25.04 controls services with service.start and stop', () async {
    await connect(legacy: true);
    await session.sharing.controlService('cifs', ServiceAction.stop);
    expect(server.calls.map((c) => c.$1), contains('service.stop'));
    expect(server.calls.map((c) => c.$1), isNot(contains('service.control')));
    expect(server.services.first['state'], 'STOPPED');
  });

  test('start on boot is updated by service id', () async {
    await connect();
    await session.sharing.setServiceAutostart(2, true);
    expect(server.services[1]['enable'], isTrue);
  });

  test('SMB read-only uses the field name the server uses', () async {
    await connect();
    expect((await session.sharing.smbShares()).single.readOnlyKey, 'readonly');
    await session.close();
    await server.close();

    await connect(legacy: true);
    final share = (await session.sharing.smbShares()).single;
    expect(share.readOnlyKey, 'ro');
    expect(share.name, 'media');
    expect(share.comment, 'Movies');
  });

  test('SMB and NFS shares can be created, changed and deleted', () async {
    await connect();
    await session.sharing.createSmbShare(
      name: 'backups',
      path: '/mnt/tank/backups',
    );
    expect(server.smbShares.last['name'], 'backups');
    await session.sharing.updateSmbShare(2, {'enabled': false});
    expect(server.smbShares.last['enabled'], isFalse);
    await session.sharing.deleteSmbShare(2);
    expect(server.smbShares, hasLength(1));

    final nfs = (await session.sharing.nfsShares()).single;
    expect(nfs.readOnly, isTrue);
    expect(nfs.networks, ['192.168.1.0/24']);
    await session.sharing.createNfsShare(
      path: '/mnt/tank/vmstore',
      readOnly: false,
    );
    expect(server.nfsShares.last['ro'], isFalse);
    await session.sharing.deleteNfsShare(1);
    expect(server.nfsShares.map((s) => s['path']), ['/mnt/tank/vmstore']);
  });

  test('block sharing reads iSCSI everywhere and NVMe-oF on 25.10+', () async {
    await connect();
    expect((await session.sharing.iscsiTargets()).single.alias, 'VM disks');
    expect(
      (await session.sharing.iscsiExtents()).single.source,
      'zvol/tank/vm',
    );
    expect(await session.sharing.hasNvmet(), isTrue);
    expect((await session.sharing.nvmetSubsystems()).single.name, 'fast');
    await session.close();
    await server.close();

    await connect(legacy: true);
    expect(await session.sharing.hasNvmet(), isFalse);
  });
}
