import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/wait_for_server.dart';
import 'package:truenas_mobile/core/wol/wake_on_lan.dart';
import 'package:truenas_mobile/features/instances/instances_screen.dart';
import 'package:truenas_mobile/features/server/server_screen.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_truenas_server.dart';
import '../../support/memory_store.dart';
import '../../support/wol_fakes.dart';

const _fast = ServerWaitTiming(
  interval: Duration(milliseconds: 50),
  timeout: Duration(seconds: 2),
  downInterval: Duration(milliseconds: 50),
  downLimit: Duration(seconds: 2),
);

void main() {
  late ProviderContainer container;
  late FakeTrueNasServer server;
  late int port;

  setUp(() => HttpOverrides.global = null);

  /// Lets real sockets and timers run between frames.
  Future<void> settle(WidgetTester tester, {int rounds = 10}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  /// Saves one server at [port] and opens [home] with the wait speeded up.
  Future<void> open(
    WidgetTester tester, {
    required Widget Function() home,
    WakeOnLanSettings? wol,
    ServerWaitTiming timing = _fast,
    FakeWakeOnLanSender? sender,
  }) async {
    await tester.runAsync(() async {
      final store = MemoryStore();
      await InstanceRepository(store).save([
        ServerInstance(
          id: '1',
          name: 'Home',
          url: 'http://127.0.0.1:$port',
          authMethod: AuthMethod.password,
          username: 'truenas_admin',
          secret: 'secret',
          wol: wol,
        ),
      ]);
      container = ProviderContainer(
        overrides: [
          instanceRepositoryProvider.overrideWithValue(
            InstanceRepository(store),
          ),
          serverWaitTimingProvider.overrideWithValue(timing),
          if (sender != null) wakeOnLanSenderProvider.overrideWithValue(sender),
        ],
      );
      await container.read(instancesProvider.future);
    });
    await tester.runAsync(
      () => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: home(),
          ),
        ),
      ),
    );
    await settle(tester, rounds: 2);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 200));
      container.dispose();
      await server.close().catchError((_) {});
    });
  }

  /// A server that was there, so its port is free to come up on later.
  Future<void> stoppedServer(WidgetTester tester) => tester.runAsync(() async {
    server = await FakeTrueNasServer.start();
    port = server.port;
    await server.close();
  });

  testWidgets('a woken server is opened once it answers', (tester) async {
    await stoppedServer(tester);
    await open(
      tester,
      home: () => const ServerScreen('1', wait: ServerWait.wake),
    );
    expect(find.text('Waiting for Home to start…'), findsOneWidget);
    expect(find.text('Stop waiting'), findsOneWidget);

    await tester.runAsync(() async {
      server = await FakeTrueNasServer.start(port: port);
    });
    await settle(tester);
    expect(find.text('Waiting for Home to start…'), findsNothing);
    expect(find.text('TrueNAS version'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a server that never comes up ends in an error', (tester) async {
    await stoppedServer(tester);
    await open(
      tester,
      home: () => const ServerScreen('1', wait: ServerWait.wake),
      timing: const ServerWaitTiming(
        interval: Duration(milliseconds: 20),
        timeout: Duration(milliseconds: 100),
      ),
    );
    await settle(tester, rounds: 8);
    expect(find.textContaining('did not come online in time'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await close(tester);
  });

  testWidgets('waiting can be stopped', (tester) async {
    await stoppedServer(tester);
    await open(
      tester,
      home: () => const ServerScreen('1', wait: ServerWait.wake),
    );
    await tester.tap(find.text('Stop waiting'));
    await tester.pump();
    expect(find.text('Connection cancelled.'), findsOneWidget);
    expect(find.text('Waiting for Home to start…'), findsNothing);

    // A server that answers afterwards is not opened behind the user's back.
    await tester.runAsync(() async {
      server = await FakeTrueNasServer.start(port: port);
    });
    await settle(tester, rounds: 6);
    expect(find.text('TrueNAS version'), findsNothing);
    await close(tester);
  });

  testWidgets('a restart first waits for the server to go down', (
    tester,
  ) async {
    await tester.runAsync(() async {
      server = await FakeTrueNasServer.start();
      port = server.port;
    });
    await open(
      tester,
      home: () => const ServerScreen('1', wait: ServerWait.restart),
    );
    // Still answering: that is not it being back.
    await settle(tester, rounds: 4);
    expect(find.text('Waiting for Home to shut down…'), findsOneWidget);
    expect(find.text('TrueNAS version'), findsNothing);

    await tester.runAsync(() => server.close());
    await settle(tester, rounds: 4);
    expect(find.text('Waiting for Home to start…'), findsOneWidget);

    await tester.runAsync(() async {
      server = await FakeTrueNasServer.start(port: port);
    });
    await settle(tester);
    expect(find.text('TrueNAS version'), findsOneWidget);
    await close(tester);
  });

  testWidgets('the wake button on the server list waits for the server', (
    tester,
  ) async {
    await stoppedServer(tester);
    final sender = FakeWakeOnLanSender();
    await open(
      tester,
      home: () => const InstancesScreen(),
      wol: const WakeOnLanSettings(mac: 'AA:BB:CC:DD:EE:FF'),
      sender: sender,
    );
    await settle(tester, rounds: 2);
    // Tapped with real timers, as the screen it opens polls with them.
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Wake up'));
      await tester.pump();
    });
    await tester.pump(const Duration(seconds: 1));
    await settle(tester, rounds: 2);
    expect(sender.sent, hasLength(1));
    expect(find.text('Waiting for Home to start…'), findsOneWidget);

    await tester.runAsync(() async {
      server = await FakeTrueNasServer.start(port: port);
    });
    await settle(tester);
    expect(find.text('TrueNAS version'), findsOneWidget);
    await close(tester);
  });

  testWidgets('the wake button on the error screen waits too', (tester) async {
    await stoppedServer(tester);
    final sender = FakeWakeOnLanSender();
    await open(
      tester,
      home: () => const ServerScreen('1'),
      wol: const WakeOnLanSettings(mac: 'AA:BB:CC:DD:EE:FF'),
      sender: sender,
    );
    await settle(tester, rounds: 4);
    expect(find.text('Wake up'), findsOneWidget);
    await tester.tap(find.text('Wake up'));
    await tester.pump();
    await settle(tester, rounds: 2);
    expect(sender.sent, hasLength(1));
    expect(find.text('Waiting for Home to start…'), findsOneWidget);
    await close(tester);
  });
}
