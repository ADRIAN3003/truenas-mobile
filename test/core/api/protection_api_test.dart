import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/models/protection.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';

import '../../support/fake_truenas_server.dart';

void main() {
  late FakeTrueNasServer server;
  late TrueNasSession session;

  setUp(() async {
    server = await FakeTrueNasServer.start();
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
  });

  tearDown(() async {
    await session.close();
    await server.close();
  });

  List<dynamic> paramsOf(String method) =>
      server.calls.lastWhere((c) => c.$1 == method).$2;

  test('lists only the kinds the server has', () async {
    server.protection.remove('cloud_backup');
    final tasks = await session.protection.allTasks();
    expect(tasks.keys, [
      ProtectionKind.snapshot,
      ProtectionKind.replication,
      ProtectionKind.cloudSync,
      ProtectionKind.rsync,
    ]);
  });

  test('normalises state from zettarepl and from jobs', () async {
    final tasks = await session.protection.allTasks();
    final snapshot = tasks[ProtectionKind.snapshot]!.single;
    expect(snapshot.name, 'tank/media');
    expect(snapshot.status, TaskStatus.success);
    expect(snapshot.schedule, SnapshotSchedule.hourly);
    expect(snapshot.lifetimeValue, 2);
    expect(snapshot.lifetimeUnit, LifetimeUnit.week);
    expect(snapshot.recursive, isTrue);
    expect(snapshot.lastRun, isNotNull);

    final replication = tasks[ProtectionKind.replication]!.single;
    expect(replication.status, TaskStatus.failed);
    expect(replication.error, 'No route to host');
    expect(replication.detail, 'PUSH tank/media → backup/media');

    final cloud = tasks[ProtectionKind.cloudSync]!.single;
    expect(cloud.name, 'Photos to B2');
    expect(cloud.status, TaskStatus.running);
    expect(cloud.progress, 42);
    expect(cloud.enabled, isFalse);
    expect(cloud.detail, 'PUSH /mnt/tank/photos → Backblaze');
  });

  test('run, stop, enable and delete call the right methods', () async {
    final tasks = await session.protection.allTasks();
    final snapshot = tasks[ProtectionKind.snapshot]!.single;
    final replication = tasks[ProtectionKind.replication]!.single;
    final cloud = tasks[ProtectionKind.cloudSync]!.single;

    await session.protection.runNow(snapshot);
    expect(paramsOf('pool.snapshottask.run'), [1]);
    await session.protection.runNow(replication);
    expect(paramsOf('replication.run'), [1]);
    await session.protection.runNow(cloud);
    expect(paramsOf('cloudsync.sync'), [1]);
    await session.protection.abort(cloud);
    expect(paramsOf('cloudsync.abort'), [1]);

    await session.protection.setEnabled(cloud, true);
    expect(server.protection['cloudsync']!.single['enabled'], isTrue);

    await session.protection.delete(snapshot);
    expect(server.protection['pool.snapshottask'], isEmpty);
  });

  test('creates snapshot tasks with a preset schedule', () async {
    await session.protection.createSnapshotTask(
      dataset: 'tank',
      recursive: false,
      lifetimeValue: 30,
      lifetimeUnit: LifetimeUnit.day,
      schedule: SnapshotSchedule.daily,
    );
    expect(paramsOf('pool.snapshottask.create').single, {
      'dataset': 'tank',
      'recursive': false,
      'lifetime_value': 30,
      'lifetime_unit': 'DAY',
      'naming_schema': 'auto-%Y-%m-%d_%H-%M',
      'schedule': {
        'minute': '0',
        'hour': '0',
        'dom': '*',
        'month': '*',
        'dow': '*',
        'begin': '00:00',
        'end': '23:59',
      },
      'enabled': true,
    });
  });

  test('unknown schedules fall back to cron text', () {
    final task = ProtectionTask.fromJson(ProtectionKind.snapshot, {
      'id': 1,
      'dataset': 'tank',
      'schedule': {
        'minute': '15',
        'hour': '*/6',
        'dom': '*',
        'month': '*',
        'dow': '*',
      },
      'state': {'state': 'PENDING'},
    });
    expect(task.schedule, '15 */6 * * *');
    expect(task.status, TaskStatus.waiting);
  });

  test('rsync destinations read the way rsync writes them', () {
    String detail(Map<String, dynamic> json) => ProtectionTask.fromJson(
      ProtectionKind.rsync,
      {'id': 1, 'direction': 'PUSH', 'path': '/mnt/tank/media', ...json},
    ).detail;
    expect(
      detail({'mode': 'MODULE', 'remotehost': 'nas', 'remotemodule': 'media'}),
      'PUSH /mnt/tank/media → nas::media',
    );
    expect(
      detail({
        'mode': 'MODULE',
        'remotehost': 'nas',
        'remotemodule': 'media',
        'remotepath': '/films',
      }),
      'PUSH /mnt/tank/media → nas::media/films',
    );
    expect(
      detail({
        'mode': 'SSH',
        'ssh_credentials': {'id': 3, 'name': 'backup-box'},
        'remotepath': '/srv/media',
      }),
      'PUSH /mnt/tank/media → backup-box:/srv/media',
    );
  });
}
