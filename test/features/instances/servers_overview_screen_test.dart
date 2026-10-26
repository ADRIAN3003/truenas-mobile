import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/overview/server_overview.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';
import 'package:truenas_mobile/features/instances/servers_overview_screen.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_truenas_server.dart';
import '../../support/memory_store.dart';

void main() {
  late FakeTrueNasServer home;
  late FakeTrueNasServer office;
  late ProviderContainer container;

  setUp(() => HttpOverrides.global = null);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  ServerInstance instance(String id, String name, int port, {String? secret}) =>
      ServerInstance(
        id: id,
        name: name,
        url: 'http://127.0.0.1:$port',
        authMethod: AuthMethod.password,
        username: 'truenas_admin',
        secret: secret ?? 'secret',
      );

  /// Opens the overview of a healthy [home], an [office] whose password the
  /// saved server has wrong and a server nobody listens on.
  Future<void> open(
    WidgetTester tester, {
    ServerOverviewLoader? loader,
    void Function(FakeTrueNasServer home)? before,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      home = await FakeTrueNasServer.start();
      office = await FakeTrueNasServer.start();
      before?.call(home);
      final dead = await FakeTrueNasServer.start();
      final deadPort = dead.port;
      await dead.close();
      final store = MemoryStore();
      await InstanceRepository(store).save([
        instance('1', 'Home', home.port),
        instance('2', 'Office', office.port, secret: 'wrong'),
        instance('3', 'Garage', deadPort),
      ]);
      container = ProviderContainer(
        overrides: [
          instanceRepositoryProvider.overrideWithValue(
            InstanceRepository(store),
          ),
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
            home: ServersOverviewScreen(loader: loader),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    // Disposing the screen closes its sessions, which needs real timers.
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 200));
      container.dispose();
      await home.close();
      await office.close();
    });
  }

  testWidgets('shows pools, alerts and running jobs of a server', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('1 pool healthy'), findsOneWidget);
    // The dismissed alert does not count.
    expect(find.text('1 active alert · 1 critical'), findsOneWidget);
    expect(find.text('Scrub · tank'), findsOneWidget);
    expect(find.text('40 %'), findsOneWidget);
    expect(find.text('Problem'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a server that cannot be looked at says why', (tester) async {
    await open(tester);

    expect(find.text('Office'), findsOneWidget);
    expect(find.text('The server refused the saved sign-in.'), findsOneWidget);
    expect(find.text('Garage'), findsOneWidget);
    expect(find.text("Can't reach the server."), findsOneWidget);
    expect(find.text('Offline'), findsNWidgets(2));
    expect(find.text('3 servers need attention'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a server that needs the user is not reported as down', (
    tester,
  ) async {
    await open(
      tester,
      loader: ServerOverviewLoader(
        connect: (server) async => throw const ConnectCancelled(),
      ),
    );

    expect(
      find.text(
        'Open this server once to trust its certificate or enter the 2FA code.',
      ),
      findsNWidgets(3),
    );
    await close(tester);
  });

  testWidgets('a server without alerts is healthy', (tester) async {
    await open(
      tester,
      before: (home) {
        home.alerts.clear();
      },
    );
    // Home alone is fine, the other two are not.
    expect(find.text('Healthy'), findsOneWidget);
    expect(find.text('No active alerts'), findsOneWidget);
    expect(find.text('2 servers need attention'), findsOneWidget);
    await close(tester);
  });
}
