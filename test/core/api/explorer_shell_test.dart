import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/api/api_exception.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
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

  test('lists every method sorted, fetched once', () async {
    final methods = await session.explorer.methods();
    expect(methods.map((m) => m.name), [
      'pool.query',
      'system.info',
      'test.fail',
      'test.job',
      'user.update',
    ]);
    await session.explorer.methods();
    expect(
      server.calls.where((c) => c.$1 == 'core.get_methods' && c.$2.isEmpty),
      hasLength(1),
    );
    expect(methods.first.summary, 'Query pools.');
  });

  test('runs methods and follows jobs', () async {
    final methods = await session.explorer.methods();
    final info = methods.firstWhere((m) => m.name == 'system.info');
    expect(await session.explorer.run(info, []), {
      'hostname': 'nas',
      'version': '25.10.7',
    });
    final job = methods.firstWhere((m) => m.name == 'test.job');
    int? started;
    final result = await session.explorer.run(job, [
      'FAST',
    ], onJobStarted: (id) => started = id);
    expect(started, isNotNull);
    expect(result, isTrue);
  });

  test('server errors carry the reason', () async {
    final methods = await session.explorer.methods();
    final fail = methods.firstWhere((m) => m.name == 'test.fail');
    expect(
      () => session.explorer.run(fail, ['x']),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Bad name'),
        ),
      ),
    );
  });

  test('shell connects with a one-time token and streams both ways', () async {
    final shell = await session.openShell();
    expect(server.shellTokenParams, [300, <String, Object?>{}, true, true]);
    expect(server.shellOptions, <String, dynamic>{});
    expect(shell.id, 'shell-1');
    final output = StringBuffer();
    final done = shell.output
        .transform(const Utf8Decoder())
        .forEach(output.write);
    shell.write('ls\r');
    await shell.resize(100, 30);
    expect(server.shellResizes.single, ['shell-1', 100, 30]);
    shell.write('exit\r');
    await done;
    expect(server.shellInput.toString(), 'ls\rexit\r');
    expect(output.toString(), startsWith('truenas# you typed: ls'));
  });

  test('shell reports a refused token', () async {
    server.shellDenied = true;
    await expectLater(
      session.openShell(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Invalid token',
        ),
      ),
    );
  });
}
