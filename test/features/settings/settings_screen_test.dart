import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:truenas_mobile/app.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/settings/app_settings.dart';
import 'package:truenas_mobile/core/settings/settings_provider.dart';
import 'package:truenas_mobile/core/settings/system_language.dart';
import 'package:truenas_mobile/features/updates/updates_provider.dart';
import 'package:truenas_mobile/shared/haptics.dart';

import '../../support/language_fakes.dart';
import '../../support/memory_store.dart';
import '../../support/update_fakes.dart';

void main() {
  late MemoryStore serverStore;
  late MemoryStore settingsStore;
  late ProviderContainer container;

  setUp(() {
    serverStore = MemoryStore();
    settingsStore = MemoryStore();
    PackageInfo.setMockInitialValues(
      appName: 'TrueNAS Mobile',
      packageName: 'hu.adrian.truenasmobile',
      version: '0.1.2',
      buildNumber: '3',
      buildSignature: '',
    );
  });

  tearDown(() => Haptics.enabled = true);

  Future<void> open(
    WidgetTester tester, {
    List<ServerInstance>? servers,
    List<Override> overrides = const [],
  }) async {
    if (servers != null) await InstanceRepository(serverStore).save(servers);
    // Tall enough that every row is built.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        instanceRepositoryProvider.overrideWithValue(
          InstanceRepository(serverStore),
        ),
        settingsRepositoryProvider.overrideWithValue(
          SettingsRepository(settingsStore),
        ),
        updateCheckerProvider.overrideWithValue(
          FakeGitHub([releaseJson('v0.1.2', body: 'First notes')]).checker,
        ),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TrueNasMobileApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('App settings'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String row, String option) async {
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  Future<AppSettings> saved() => SettingsRepository(settingsStore).load();

  testWidgets('opens from the server list with every section', (tester) async {
    await open(tester);
    expect(find.text('App settings'), findsOneWidget);
    for (final title in [
      'Appearance',
      'General',
      'Shell',
      'Security',
      'Updates',
      'About',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    // The build number comes from the platform.
    expect(find.text('0.1.2 (3)'), findsOneWidget);
  });

  testWidgets('choosing Dark switches the whole app and is remembered', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Same as device'), findsNWidgets(2));
    await choose(tester, 'Theme', 'Dark');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(container.read(settingsProvider).theme, ThemeChoice.dark);
    expect((await saved()).theme, ThemeChoice.dark);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('choosing Magyar translates the app at once, then back', (
    tester,
  ) async {
    await open(tester);
    await choose(tester, 'Language', 'Magyar');
    expect(find.text('Alkalmazás beállításai'), findsOneWidget);
    expect((await saved()).language, 'hu');

    await choose(tester, 'Nyelv', 'Mint az eszköz');
    expect(container.read(settingsProvider).language, isNull);
    expect((await saved()).language, isNull);
  });

  group('language', () {
    testWidgets('is picked inside the app when the phone has no page for it', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Magyar'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets("opens the phone's language page for the app instead", (
      tester,
    ) async {
      final system = FakeSystemLanguage();
      await open(
        tester,
        overrides: [
          systemLanguagePageProvider.overrideWithValue(true),
          systemLanguageProvider.overrideWithValue(system),
        ],
      );
      expect(
        find.text("Opens this app's language page in your phone's settings"),
        findsOneWidget,
      );
      expect(find.text('English'), findsOneWidget);

      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      expect(system.opened, 1);
      // Nothing to pick in the app, and nothing saved from it.
      expect(find.byType(BottomSheet), findsNothing);
      expect((await saved()).language, isNull);
    });

    testWidgets("the phone's page decides, not an old in-app choice", (
      tester,
    ) async {
      await open(
        tester,
        overrides: [
          initialSettingsProvider.overrideWithValue(
            const AppSettings(language: 'hu'),
          ),
          systemLanguagePageProvider.overrideWithValue(true),
          systemLanguageProvider.overrideWithValue(FakeSystemLanguage()),
        ],
      );
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
        isNull,
      );
      expect(find.text('App settings'), findsOneWidget);
    });

    testWidgets('says so when the settings cannot be opened', (tester) async {
      await open(
        tester,
        overrides: [
          systemLanguagePageProvider.overrideWithValue(true),
          systemLanguageProvider.overrideWithValue(
            FakeSystemLanguage(failToOpen: true),
          ),
        ],
      );
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      expect(
        find.text("Could not open your phone's settings."),
        findsOneWidget,
      );
    });
  });

  testWidgets('the haptics switch turns the app\'s taps off', (tester) async {
    await open(tester);
    expect(Haptics.enabled, isTrue);
    await tester.tap(find.text('Haptic feedback'));
    await tester.pumpAndSettle();
    expect(Haptics.enabled, isFalse);
    expect((await saved()).haptics, isFalse);
  });

  testWidgets('ask before closing can be turned off', (tester) async {
    await open(tester);
    await tester.tap(find.text('Ask before closing'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).confirmLeave, isFalse);
    expect((await saved()).confirmLeave, isFalse);
  });

  testWidgets('checking for updates on start can be turned off', (
    tester,
  ) async {
    await open(tester);
    expect(container.read(settingsProvider).checkForUpdates, isTrue);
    await tester.tap(find.text('Check on start'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).checkForUpdates, isFalse);
    expect((await saved()).checkForUpdates, isFalse);
  });

  testWidgets('the update rows open the update and release notes screens', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(find.text('Software update'), findsOneWidget);
    expect(find.text("You're up to date"), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Release notes'));
    await tester.pumpAndSettle();
    expect(find.text('First notes'), findsOneWidget);
  });

  testWidgets('shell font size and extra keys are saved', (tester) async {
    await open(tester);
    await tester.drag(find.byType(Slider), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(
      container.read(settingsProvider).shellFontSize,
      AppSettings.maxShellFontSize,
    );
    await tester.tap(find.text('Extra keys'));
    await tester.pumpAndSettle();
    final stored = await saved();
    expect(stored.shellFontSize, AppSettings.maxShellFontSize);
    expect(stored.shellExtraKeys, isFalse);
  });

  group('trusted certificates', () {
    const pinned = ServerInstance(
      id: 'a',
      name: 'Home NAS',
      url: 'https://nas.local',
      authMethod: AuthMethod.password,
      username: 'truenas_admin',
      secret: 'pw',
      pinnedFingerprint: 'AB:CD:EF',
    );

    Future<void> openList(WidgetTester tester) async {
      await tester.tap(find.text('Trusted certificates'));
      await tester.pumpAndSettle();
    }

    testWidgets('explains when there are none', (tester) async {
      await open(tester);
      await openList(tester);
      expect(
        find.textContaining('No certificates are trusted'),
        findsOneWidget,
      );
    });

    testWidgets('lists the ones in use and forgets one after asking', (
      tester,
    ) async {
      await open(
        tester,
        servers: [
          pinned,
          const ServerInstance(
            id: 'b',
            name: 'Plain',
            url: 'https://plain.local',
            authMethod: AuthMethod.password,
            username: 'truenas_admin',
            secret: 'pw',
          ),
        ],
      );
      await openList(tester);
      expect(find.text('Home NAS'), findsOneWidget);
      expect(find.text('AB:CD:EF'), findsOneWidget);
      // A server with a normal certificate has nothing to forget.
      expect(find.text('Plain'), findsNothing);

      await tester.tap(find.text('Forget'));
      await tester.pumpAndSettle();
      expect(find.text('Forget the certificate of Home NAS?'), findsOneWidget);
      // Cancelling keeps it.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('AB:CD:EF'), findsOneWidget);

      await tester.tap(find.text('Forget'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forget').last);
      await tester.pumpAndSettle();
      expect(find.text('AB:CD:EF'), findsNothing);
      final servers = await InstanceRepository(serverStore).load();
      expect(servers.firstWhere((s) => s.id == 'a').pinnedFingerprint, isNull);
    });
  });
}
