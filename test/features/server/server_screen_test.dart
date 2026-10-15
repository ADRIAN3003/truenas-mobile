import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/features/server/server_screen.dart';
import 'package:truenas_mobile/shared/glass.dart';
import 'package:truenas_mobile/shared/theme.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_truenas_server.dart';
import '../../support/memory_store.dart';

void main() {
  late FakeTrueNasServer server;
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

  Future<void> open(
    WidgetTester tester,
    Size size, {
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      server = await FakeTrueNasServer.start();
      final store = MemoryStore();
      await InstanceRepository(store).save([
        ServerInstance(
          id: '1',
          name: 'Home',
          url: 'http://127.0.0.1:${server.port}',
          authMethod: AuthMethod.password,
          username: 'truenas_admin',
          secret: 'secret',
        ),
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
    // The screen connects from its first frame; build it with real timers
    // so the socket's ping timer isn't left in the fake test zone.
    await tester.runAsync(
      () => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light, platform: platform),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ServerScreen('1'),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    // Disposing the screen closes its session, which needs real timers.
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 200));
      container.dispose();
      await server.close();
    });
  }

  testWidgets('phones get a bottom navigation bar', (tester) async {
    await open(tester, const Size(400, 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await close(tester);
  });

  testWidgets('tablets get a navigation rail', (tester) async {
    await open(tester, const Size(1024, 768));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Storage'));
    await settle(tester);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      1,
    );
    await close(tester);
  });

  testWidgets('iPhones get a floating glass tab bar', (tester) async {
    await open(tester, const Size(400, 800), platform: TargetPlatform.iOS);
    expect(find.byType(GlassTabBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    // The bar draws each label twice: plain, and highlighted under the pill.
    await tester.tap(find.text('Storage').first);
    await settle(tester);
    expect(
      tester.widget<GlassTabBar>(find.byType(GlassTabBar)).selectedIndex,
      1,
    );
    await close(tester);
  });
}
