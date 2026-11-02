import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/api/workloads_api.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/models/vm_config.dart';
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

  group('VM editor', () {
    test('is offered only when the server has the methods', () async {
      await connect();
      expect(await session.workloads.canCreateVm(), isTrue);
      expect(await session.workloads.canEditVm(), isTrue);
      expect(await session.workloads.canDeleteVm(), isTrue);
      await session.close();
      await server.close();

      server = await FakeTrueNasServer.start();
      server.vmEditor = false;
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
      expect(await session.workloads.canCreateVm(), isFalse);
      expect(await session.workloads.canEditVm(), isFalse);
    });

    test('reads the devices of one machine in boot order', () async {
      await connect();
      final devices = await session.workloads.vmDevices(1);
      expect(devices.map((d) => d.dtype), ['DISK', 'NIC']);
      expect(devices.first.type, VmDeviceType.disk);
      expect(devices.first.detail, '/dev/zvol/tank/win11');
      expect(devices.last.detail, 'enp1s0 · 00:a0:98:11:22:33');
      expect((await session.workloads.vm(1))!.raw['cores'], 4);
      expect(await session.workloads.vm(99), isNull);
    });

    test('reads what the editors can pick from', () async {
      await connect();
      final choices = await session.workloads.vmChoices();
      expect(choices.bootloaders.keys, ['UEFI', 'UEFI_CSM']);
      expect(choices.nicAttach.keys, ['enp1s0', 'br0']);
      expect(choices.disks, {'/dev/zvol/tank/win11': 'tank/win11'});
      expect(choices.resolutions, ['1024x768', '1920x1080']);
      expect(choices.maxVcpus, 16);
      expect(await session.workloads.randomMac(), '00:a0:98:aa:bb:cc');
    });

    test('creates a machine with its devices in one call', () async {
      await connect();
      final draft = VmDraft()
        ..name = 'debian'
        ..memory = 4096;
      await session.workloads.createVm(draft.toPayload(), [
        {
          'dtype': 'DISK',
          'attributes': {'type': 'VIRTIO', 'create_zvol': true},
        },
      ]);
      final sent =
          server.calls.firstWhere((c) => c.$1 == 'vm.create').$2.single
              as Map<String, dynamic>;
      expect(sent['name'], 'debian');
      expect(sent['memory'], 4096);
      expect(sent['min_memory'], isNull);
      expect(sent['devices'], hasLength(1));
      expect(sent.containsKey('trusted_platform_module'), isFalse);
      expect(server.vms.map((v) => v['name']), contains('debian'));
    });

    test('sends only what changed on update', () async {
      await connect();
      final vm = (await session.workloads.vm(1))!;
      final draft = VmDraft.fromJson(vm.raw);
      expect(draft.changesFrom(vm.raw), isEmpty);
      draft
        ..memory = 16384
        ..autostart = true;
      expect(draft.changesFrom(vm.raw), {'memory': 16384, 'autostart': true});
      await session.workloads.updateVm(1, draft.changesFrom(vm.raw));
      expect(server.calls.where((c) => c.$1 == 'vm.update').single.$2[1], {
        'memory': 16384,
        'autostart': true,
      });
      // Nothing to change, nothing sent.
      server.calls.clear();
      await session.workloads.updateVm(1, const {});
      expect(methods(), isNot(contains('vm.update')));
    });

    test('adds, changes and removes devices; deletes the machine', () async {
      await connect();
      final api = session.workloads;
      await api.createVmDevice(1, 'CDROM', {'path': '/mnt/tank/win11.iso'});
      expect((await api.vmDevices(1)).map((d) => d.dtype), contains('CDROM'));
      await api.updateVmDevice(11, {'type': 'VIRTIO', 'nic_attach': 'br0'});
      expect(server.calls.firstWhere((c) => c.$1 == 'vm.device.update').$2, [
        11,
        {
          'attributes': {'type': 'VIRTIO', 'nic_attach': 'br0'},
        },
      ]);
      await api.deleteVmDevice(10, removeZvol: true);
      expect(
        server.calls.firstWhere((c) => c.$1 == 'vm.device.delete').$2[1],
        containsPair('zvol', true),
      );
      await api.deleteVm(1, removeZvols: true);
      expect(server.calls.firstWhere((c) => c.$1 == 'vm.delete').$2, [
        1,
        {'zvols': true, 'force': false},
      ]);
      expect(server.vms, isEmpty);
    });
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
