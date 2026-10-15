import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/api/events.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';

import '../../support/fake_truenas_server.dart';

void main() {
  late FakeTrueNasServer server;

  setUp(() async => server = await FakeTrueNasServer.start());
  tearDown(() => server.close());

  ServerInstance instance({
    AuthMethod method = AuthMethod.password,
    String secret = 'secret',
    String url = '',
  }) => ServerInstance(
    id: '1',
    name: 'Home',
    url: url.isEmpty ? 'http://127.0.0.1:${server.port}' : url,
    authMethod: method,
    username: 'truenas_admin',
    secret: secret,
  );

  Future<bool> neverTrust(_) async => fail('no certificate prompt expected');
  Future<String?> noOtp() async => fail('no 2FA prompt expected');

  test('signs in with a password and records the API version', () async {
    final (session, updated) = await connectToInstance(
      instance(),
      confirmCertificate: neverTrust,
      askOtp: noOtp,
    );
    addTearDown(session.close);
    expect(session.userInfo?['pw_name'], 'truenas_admin');
    expect(updated.lastApiVersion, 'v25.10.5');
    expect((await session.systemInfo())['version'], '25.10.7');
  });

  test('asks for a 2FA code when the account needs one', () async {
    server.otp = '123456';
    var asked = 0;
    final (session, _) = await connectToInstance(
      instance(),
      confirmCertificate: neverTrust,
      askOtp: () async {
        asked++;
        return '123456';
      },
    );
    addTearDown(session.close);
    expect(asked, 1);
  });

  test('cancelling the 2FA prompt cancels the connection', () async {
    server.otp = '123456';
    await expectLater(
      connectToInstance(
        instance(),
        confirmCertificate: neverTrust,
        askOtp: () async => null,
      ),
      throwsA(isA<ConnectCancelled>()),
    );
  });

  test('reports rejected credentials', () async {
    await expectLater(
      connectToInstance(
        instance(secret: 'wrong'),
        confirmCertificate: neverTrust,
        askOtp: noOtp,
      ),
      throwsA(isA<LoginRejected>()),
    );
  });

  test('pins a certificate the user trusts', () async {
    final tlsServer = await FakeTrueNasServer.start(tls: testTlsContext());
    addTearDown(tlsServer.close);
    final (session, updated) = await connectToInstance(
      instance(
        method: AuthMethod.apiKey,
        secret: '1-abcdef',
        url: 'https://localhost:${tlsServer.port}',
      ),
      confirmCertificate: (cert) async => true,
      askOtp: noOtp,
    );
    addTearDown(session.close);
    expect(updated.pinnedFingerprint, testCertFingerprint);
  });

  group('after the connection drops', () {
    Future<TrueNasSession> signIn() async {
      server.requireLogin = true;
      final (session, _) = await connectToInstance(
        instance(),
        confirmCertificate: neverTrust,
        askOtp: noOtp,
      );
      addTearDown(session.close);
      return session;
    }

    int logins() => server.calls.where((c) => c.$1 == 'auth.login_ex').length;

    test('the next call reconnects and signs in again', () async {
      final session = await signIn();
      await server.dropConnections();
      await pumpEventQueue();
      expect((await session.systemInfo())['version'], '25.10.7');
      expect(logins(), 2);
      expect(server.connectedPaths, hasLength(2));
    });

    test('ensureAlive reconnects a dead socket and keeps a live one', () async {
      final session = await signIn();
      await session.ensureAlive();
      expect(logins(), 1);
      await server.dropConnections();
      await pumpEventQueue();
      await session.ensureAlive();
      expect(logins(), 2);
    });

    test('event subscriptions are renewed on the new connection', () async {
      final session = await signIn();
      final updates = <CollectionUpdate>[];
      final sub = session.client
          .subscribe('reporting.realtime')
          .listen(updates.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(updates, hasLength(1));
      await server.dropConnections();
      await pumpEventQueue();
      await session.ensureAlive();
      await pumpEventQueue();
      expect(server.subscriptions, [
        'reporting.realtime',
        'reporting.realtime',
      ]);
      expect(updates, hasLength(2));
    });

    test('opens the shell at the path the TrueNAS web server serves', () async {
      final session = await signIn();
      await server.dropConnections();
      await pumpEventQueue();
      final shell = await session.openShell();
      addTearDown(shell.close);
      expect(shell.id, 'shell-1');
    });
  });
}
