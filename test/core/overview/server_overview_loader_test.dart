import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/notifications/alert_watcher.dart';
import 'package:truenas_mobile/core/overview/server_overview.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';

import '../../support/fake_truenas_server.dart';

void main() {
  late FakeTrueNasServer server;

  setUp(() async {
    HttpOverrides.global = null;
    server = await FakeTrueNasServer.start();
  });
  tearDown(() => server.close());

  test('a sign-in that ends after the overview closed is closed too', () async {
    final signedIn = Completer<void>();
    TrueNasSession? made;
    final loader = ServerOverviewLoader(
      connect: (instance) async {
        await signedIn.future;
        return made = await connectQuietly(instance);
      },
    );
    final entries = <OverviewEntry>[];
    final looking = loader.refresh([
      ServerInstance(
        id: '1',
        name: 'Home',
        url: 'http://127.0.0.1:${server.port}',
        authMethod: AuthMethod.password,
        username: 'truenas_admin',
        secret: 'secret',
      ),
    ], entries.add);
    await loader.close();
    signedIn.complete();
    await looking;
    expect(made, isNotNull);
    expect(made!.client.isClosed, isTrue);
  });
}
