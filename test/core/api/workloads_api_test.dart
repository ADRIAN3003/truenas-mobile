import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/api/workloads_api.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/models/workloads.dart';
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

  List<String> methods() => server.calls.map((c) => c.$1).toList();

  test('apps parse metadata, portals and upgrades', () async {
    await connect();
    final app = (await session.workloads.apps()).single;
    expect(app.title, 'Jellyfin');
    expect(app.state, WorkloadState.running);
    expect(app.upgradeAvailable, isTrue);
    expect(app.latestVersion, '1.2.4');
    expect(app.portals, {'Web UI': 'http://nas:30013/'});
    expect(app.images, ['jellyfin/jellyfin:10.10.7']);
  });

  test('app actions run as jobs and are waited for', () async {
    await connect();
    await session.workloads.appAction('jellyfin', WorkloadAction.stop);
    expect(server.apps.single['state'], 'STOPPED');
    await session.workloads.appAction('jellyfin', WorkloadAction.restart);
    expect(methods(), containsAllInOrder(['app.redeploy', 'core.get_jobs']));
    await session.workloads.appAction('jellyfin', WorkloadAction.delete);
    expect(server.calls.last.$1, 'core.get_jobs');
    expect(server.calls.firstWhere((c) => c.$1 == 'app.delete').$2[1], {
      'remove_images': true,
      'remove_ix_volumes': false,
    });
    expect(server.apps, isEmpty);
  });

  test('VMs count every vCPU and stop gracefully', () async {
    await connect();
    final vm = (await session.workloads.vms()).single;
    expect(vm.vcpus, 8);
    expect(vm.memoryMib, 8192);
    expect(vm.state, WorkloadState.stopped);
    await session.workloads.vmAction(1, WorkloadAction.start);
    expect((server.vms.single['status'] as Map)['state'], 'RUNNING');
    await session.workloads.vmAction(1, WorkloadAction.stop);
    expect(server.calls.firstWhere((c) => c.$1 == 'vm.stop').$2[1], {
      'force': false,
      'force_after_timeout': true,
    });
    await session.workloads.vmAction(1, WorkloadAction.powerOff);
    expect(methods(), contains('vm.poweroff'));
  });

  test('26+ servers use container.*', () async {
    await connect();
    expect(
      await session.workloads.containerBackend(),
      ContainerBackend.containers,
    );
    final container = (await session.workloads.containers()).single;
    expect(container.id, '3');
    expect(container.description, 'Build box');
    expect(await session.workloads.containerActions(), [
      WorkloadAction.start,
      WorkloadAction.stop,
    ]);
    await session.workloads.containerAction(container, WorkloadAction.stop);
    expect(server.calls.firstWhere((c) => c.$1 == 'container.stop').$2[0], 3);
  });

  test('25.x servers use Incus virt.instance.*', () async {
    await connect(legacy: true);
    expect(await session.workloads.containerBackend(), ContainerBackend.incus);
    final container = (await session.workloads.containers()).single;
    expect(container.id, 'debian');
    expect(container.description, 'Debian bookworm');
    await session.workloads.containerAction(container, WorkloadAction.restart);
    expect(server.calls.firstWhere((c) => c.$1 == 'virt.instance.restart').$2, [
      'debian',
      {'timeout': 60, 'force': false},
    ]);
  });

  group('Update all', () {
    test(
      'is one core.bulk job over app.upgrade, not one call per app',
      () async {
        await connect();
        expect(await session.workloads.canBulk(), isTrue);
        final id = await session.workloads.bulk(AppBulkAction.upgrade, [
          'jellyfin',
        ]);
        expect(server.bulkCalls, hasLength(1));
        expect(server.bulkCalls.single.$1, 'app.upgrade');
        expect(server.bulkCalls.single.$2, [
          ['jellyfin'],
        ]);
        expect(methods(), isNot(contains('app.upgrade')));
        final run = (await session.workloads.bulkRun(id))!;
        expect(run.jobId, id);
        expect(run.apps, ['jellyfin']);
        expect(run.isActive, isFalse);
        expect(run.failed, isEmpty);
      },
    );

    test('a held job is found again as the active run', () async {
      await connect();
      expect(await session.workloads.activeBulkRun(), isNull);
      server.holdBulk = true;
      final id = await session.workloads.bulk(AppBulkAction.upgrade, [
        'jellyfin',
      ]);
      final run = (await session.workloads.activeBulkRun())!;
      expect(run.jobId, id);
      expect(run.isActive, isTrue);
      expect(run.failed, isEmpty);
      expect(server.apps.single['upgrade_available'], isTrue);

      server.finishBulk();
      expect(await session.workloads.activeBulkRun(), isNull);
      expect(server.apps.single['upgrade_available'], isFalse);
    });

    test('names the apps the server could not update', () async {
      await connect();
      server.failingUpgrades.add('jellyfin');
      final id = await session.workloads.bulk(AppBulkAction.upgrade, [
        'jellyfin',
      ]);
      final run = (await session.workloads.bulkRun(id))!;
      expect(run.failed, {'jellyfin': '[EFAULT] Upgrade failed'});
    });

    test('other bulk jobs are not an Update all run', () {
      expect(
        AppBulkRun.fromJob({
          'id': 1,
          'method': 'core.bulk',
          'arguments': [
            'app.delete',
            [
              ['x'],
            ],
          ],
          'state': 'RUNNING',
        }),
        isNull,
      );
    });
  });
}
