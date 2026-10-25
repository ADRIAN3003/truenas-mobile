import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/api/system_api.dart';
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

  List<dynamic> paramsOf(String method) =>
      server.calls.lastWhere((c) => c.$1 == method).$2;

  test('users hide system accounts unless asked', () async {
    await connect();
    final users = await session.system.users();
    expect(users.map((u) => u.username), ['alice']);
    expect(users.single.twoFactor, isTrue);
    expect(users.single.fullName, 'Alice Smith');
    final all = await session.system.users(builtin: true);
    expect(all.map((u) => u.username), ['root', 'alice']);
  });

  test('user create, lock and delete send the right options', () async {
    await connect();
    await session.system.createUser(
      username: 'bob',
      fullName: 'Bob',
      password: 'pw',
    );
    expect(paramsOf('user.create').single, {
      'username': 'bob',
      'full_name': 'Bob',
      'password': 'pw',
      'group_create': true,
      'smb': true,
    });
    await session.system.setUserLocked(70, true);
    expect(server.users.firstWhere((u) => u['id'] == 70)['locked'], isTrue);
    await session.system.deleteUser(70);
    expect(paramsOf('user.delete')[1], {'delete_group': true});
    await session.system.deleteGroup(40);
    expect(paramsOf('group.delete')[1], {'delete_users': false});
  });

  test('groups count their members', () async {
    await connect();
    final group = (await session.system.groups()).single;
    expect(group.name, 'alice');
    expect(group.members, 1);
  });

  test('groups load on 25.04, sorted by name', () async {
    await connect(legacy: true);
    server.groups.insert(0, {
      'id': 41,
      'gid': 3001,
      'group': 'Media',
      'name': 'Media',
      'builtin': false,
      'users': [],
      'local': true,
    });
    final groups = await session.system.groups();
    expect(groups.map((g) => g.name), ['alice', 'Media']);
  });

  test('creating an API key returns its secret once', () async {
    await connect();
    final key = await session.system.createApiKey('backup', 'alice');
    expect(key, '2-SECRETKEY');
    final keys = await session.system.apiKeys();
    expect(keys.map((k) => k.name), ['home-assistant', 'backup']);
    expect(keys.first.createdAt, isNotNull);
  });

  test('network summary maps addresses to interfaces', () async {
    await connect();
    final summary = await session.system.networkSummary();
    expect(summary.addresses['enp1s0'], ['192.168.1.10/24', 'fe80::1/64']);
    expect(summary.defaultRoutes, ['192.168.1.1']);
    expect(summary.nameservers, ['1.1.1.1', '9.9.9.9']);
    final interfaces = await session.system.interfaces();
    expect(interfaces.first.linkUp, isTrue);
    expect(interfaces.first.dhcp, isTrue);
    expect(interfaces.last.linkUp, isFalse);
    expect(await session.system.hostname(), 'nas');
  });

  test('update check uses update.status on 25.10 and newer', () async {
    await connect();
    final update = await session.system.checkForUpdate();
    expect(update.available, isTrue);
    expect(update.version, '25.10.8');
    expect(update.releaseNotesUrl, 'https://example.com/notes');
    expect(update.sizeBytes, 1073741824);
    expect(update.changelog, 'Fixes for SMB and apps.');
    expect(update.rebootRequired, isFalse);
    await session.system.applyUpdate();
    expect(paramsOf('update.run').single, {'reboot': true});
    await session.system.applyUpdate(reboot: false);
    expect(server.calls.where((c) => c.$1 == 'update.run').last.$2.single, {
      'reboot': false,
    });
    server.rebootRequired = true;
    expect((await session.system.checkForUpdate()).rebootRequired, isTrue);
  });

  test('update check uses update.check_available on 25.04', () async {
    await connect(legacy: true);
    final update = await session.system.checkForUpdate();
    expect(update.available, isTrue);
    expect(update.version, '25.10.8');
    await session.system.applyUpdate();
    expect(paramsOf('update.update').single, {'reboot': true});
    server.availableUpdate = null;
    expect((await session.system.checkForUpdate()).available, isFalse);
    server.rebootRequired = true;
    expect((await session.system.checkForUpdate()).rebootRequired, isTrue);
  });

  test('boot environments are newest first and can be changed', () async {
    await connect();
    final envs = await session.system.bootEnvironments();
    expect(envs.map((e) => e.id), ['25.10.7', '25.10.6']);
    expect(envs.first.active, isTrue);
    await session.system.activateBootEnvironment('25.10.6');
    expect(paramsOf('boot.environment.activate').single, {'id': '25.10.6'});
    await session.system.keepBootEnvironment('25.10.6', true);
    expect(paramsOf('boot.environment.keep').single, {
      'id': '25.10.6',
      'value': true,
    });
    await session.system.deleteBootEnvironment('25.10.6');
    expect(server.bootEnvironments.map((e) => e['id']), ['25.10.7']);
  });

  test('power calls pass a reason for the audit log', () async {
    await connect();
    await session.system.reboot();
    expect(paramsOf('system.reboot'), [SystemApi.powerReason]);
    await session.system.shutdown();
    expect(paramsOf('system.shutdown'), [SystemApi.powerReason]);
  });
}
