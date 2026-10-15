import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/api/certificate_trust.dart';
import 'package:truenas_mobile/core/api/server_address.dart';
import 'package:truenas_mobile/core/api/truenas_connection.dart';

import '../../support/fake_truenas_server.dart';

void main() {
  test('connects to the newest supported API version', () async {
    final server = await FakeTrueNasServer.start();
    addTearDown(server.close);
    final connection = await TrueNasConnection.open(
      ServerAddress.tryParse('http://127.0.0.1:${server.port}')!,
    );
    addTearDown(connection.close);

    expect(connection.apiVersion, 'v25.10.5');
    expect(server.connectedPaths, ['/api/v25.10.5']);
    expect(
      await connection.client.call('system.info'),
      containsPair('hostname', 'nas'),
    );
  });

  test('falls back to current when /api/versions is missing', () async {
    final server = await FakeTrueNasServer.start(versions: null);
    addTearDown(server.close);
    final connection = await TrueNasConnection.open(
      ServerAddress.tryParse('http://127.0.0.1:${server.port}')!,
    );
    addTearDown(connection.close);
    expect(server.connectedPaths, ['/api/current']);
  });

  test('refuses servers older than 25.04', () async {
    final server = await FakeTrueNasServer.start(versions: ['v24.10']);
    addTearDown(server.close);
    await expectLater(
      TrueNasConnection.open(
        ServerAddress.tryParse('http://127.0.0.1:${server.port}')!,
      ),
      throwsA(isA<UnsupportedServerException>()),
    );
  });

  group('self-signed certificates', () {
    late FakeTrueNasServer server;
    late ServerAddress address;

    setUp(() async {
      server = await FakeTrueNasServer.start(tls: testTlsContext());
      address = ServerAddress.tryParse('https://localhost:${server.port}')!;
    });
    tearDown(() => server.close());

    test('are reported with their fingerprint when not pinned', () async {
      await expectLater(
        TrueNasConnection.open(address),
        throwsA(
          isA<UntrustedCertificateException>().having(
            (e) => e.certificate.fingerprint,
            'fingerprint',
            testCertFingerprint,
          ),
        ),
      );
    });

    test('are accepted once pinned', () async {
      final connection = await TrueNasConnection.open(
        address,
        pinnedFingerprint: testCertFingerprint,
      );
      addTearDown(connection.close);
      expect(connection.apiVersion, 'v25.10.5');
    });

    test('are reported as changed when a different one is pinned', () async {
      await expectLater(
        TrueNasConnection.open(address, pinnedFingerprint: 'AA:BB'),
        throwsA(
          isA<UntrustedCertificateException>().having(
            (e) => e.certificate.changed,
            'changed',
            isTrue,
          ),
        ),
      );
    });
  });
}
