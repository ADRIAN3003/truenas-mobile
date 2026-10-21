import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lg;
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/settings/app_settings.dart';
import 'package:truenas_mobile/core/settings/settings_provider.dart';
import 'package:truenas_mobile/core/widgets/home_widgets.dart';
import 'package:truenas_mobile/features/server/server_screen.dart';
import 'package:truenas_mobile/shared/glass.dart';
import 'package:truenas_mobile/shared/theme.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_truenas_server.dart';
import '../../support/home_widget_fakes.dart';
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
    bool fromList = false,
    String? url,
    AppSettings settings = const AppSettings(),
    List<Override> overrides = const [],
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
          url: url ?? 'http://127.0.0.1:${server.port}',
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
          initialSettingsProvider.overrideWithValue(settings),
          ...overrides,
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
            home: fromList
                ? Builder(
                    builder: (context) => Scaffold(
                      body: Center(
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const ServerScreen('1'),
                            ),
                          ),
                          child: const Text('servers'),
                        ),
                      ),
                    ),
                  )
                : const ServerScreen('1'),
          ),
        ),
      ),
    );
    if (fromList) {
      await tester.runAsync(() async {
        await tester.tap(find.text('servers'));
        await tester.pump();
      });
      // Let the page slide in.
      await tester.pump(const Duration(seconds: 1));
    }
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

  testWidgets('the app settings are one tap away inside a server', (
    tester,
  ) async {
    await open(tester, const Size(400, 800));
    await tester.tap(find.byTooltip('App settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    await close(tester);
  });

  testWidgets('an open server keeps the home screen widgets current', (
    tester,
  ) async {
    final widgets = FakeHomeWidgets();
    await open(
      tester,
      const Size(400, 800),
      overrides: [homeWidgetsBridgeProvider.overrideWithValue(widgets)],
    );
    expect(widgets.servers['1']?['pools']['items'][0]['name'], 'tank');
    expect(widgets.servers['1']?['alerts']['count'], 1);
    await close(tester);
  });

  testWidgets('with widgets switched off nothing is saved for them', (
    tester,
  ) async {
    final widgets = FakeHomeWidgets();
    await open(
      tester,
      const Size(400, 800),
      settings: const AppSettings(homeWidgets: false),
      overrides: [homeWidgetsBridgeProvider.overrideWithValue(widgets)],
    );
    expect(widgets.document, isNull);
    await close(tester);
  });

  testWidgets('a running scrub floats over the server screen', (tester) async {
    await open(tester, const Size(400, 800));
    expect(find.text('Scrub · tank'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    await close(tester);
  });

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

  testWidgets('the glass tab bar is plain, but the selected tab is accent', (
    tester,
  ) async {
    await open(tester, const Size(400, 800), platform: TargetPlatform.iOS);
    final bar = tester.widget<lg.GlassTabBar>(find.byType(lg.GlassTabBar));
    final accent = Theme.of(tester.element(find.byType(lg.GlassTabBar)))
        .colorScheme
        .primary;
    // The glass is tinted with the page colour, so the bar is dark in the
    // dark theme and light in the light one, and nothing else is coloured.
    expect(
      bar.settings?.glassColor,
      AppPalette.of(tester.element(find.byType(lg.GlassTabBar))).background
          .withValues(alpha: 0.6),
    );
    expect(bar.indicatorColor, isNull);
    expect(bar.unselectedIconColor, isNull);
    expect(bar.unselectedLabelColor, isNull);
    // The selected one is the accent colour only, and not drawn larger or
    // heavier than the rest (that clipped a half-coloured "D").
    expect(bar.selectedIconColor, accent);
    expect(bar.selectedLabelColor, accent);
    expect(bar.magnification, 1);
    expect(
      bar.selectedLabelStyle?.fontWeight,
      bar.unselectedLabelStyle?.fontWeight,
    );
    await close(tester);
  });

  group('going back to the server list', () {
    testWidgets('asks before closing an open server', (tester) async {
      await open(tester, const Size(400, 800), fromList: true);
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Disconnect from Home?'), findsOneWidget);

      // Staying keeps the server open.
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.text('Disconnect from Home?'), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Disconnect'));
        await tester.pump();
      });
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('servers'), findsOneWidget);
      await close(tester);
    });

    testWidgets('does not ask when the user turned that off', (tester) async {
      await open(
        tester,
        const Size(400, 800),
        fromList: true,
        settings: const AppSettings(confirmLeave: false),
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Disconnect from Home?'), findsNothing);
      expect(find.text('servers'), findsOneWidget);
      await close(tester);
    });

    testWidgets('asks on iOS too, with a glass dialog', (tester) async {
      await open(
        tester,
        const Size(400, 800),
        platform: TargetPlatform.iOS,
        fromList: true,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(GlassAlert), findsOneWidget);
      expect(find.text('Disconnect from Home?'), findsOneWidget);
      await close(tester);
    });

    testWidgets('does not ask when nothing is open yet', (tester) async {
      // Nothing listens here, so connecting fails and the error is shown.
      await open(
        tester,
        const Size(400, 800),
        fromList: true,
        url: 'http://127.0.0.1:1',
      );
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Disconnect from Home?'), findsNothing);
      expect(find.text('servers'), findsOneWidget);
      await close(tester);
    });
  });
}
