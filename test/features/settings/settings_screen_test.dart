import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:truenas_mobile/app.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/jobs/live_progress.dart';
import 'package:truenas_mobile/core/logging/app_log.dart';
import 'package:truenas_mobile/core/logging/log_providers.dart';
import 'package:truenas_mobile/core/models/alert.dart';
import 'package:truenas_mobile/core/notifications/alert_kind_catalog.dart';
import 'package:truenas_mobile/core/notifications/background_alerts.dart';
import 'package:truenas_mobile/core/security/biometric_auth.dart';
import 'package:truenas_mobile/core/settings/app_settings.dart';
import 'package:truenas_mobile/core/settings/settings_provider.dart';
import 'package:truenas_mobile/core/settings/system_language.dart';
import 'package:truenas_mobile/features/updates/updates_provider.dart';
import 'package:truenas_mobile/shared/haptics.dart';

import '../../support/alert_fakes.dart';
import '../../support/biometric_fakes.dart';
import '../../support/job_fakes.dart';
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

  testWidgets('the error log opens from About', (tester) async {
    final log = AppLog();
    log.warning('rpc', 'pool.query failed');
    await open(tester, overrides: [appLogProvider.overrideWithValue(log)]);
    // One entry, counted on the row.
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.text('Error log'));
    await tester.pumpAndSettle();
    expect(find.text('pool.query failed'), findsOneWidget);
  });

  group('default server', () {
    const home = ServerInstance(
      id: 'a',
      name: 'Home',
      url: 'https://home.local',
      authMethod: AuthMethod.apiKey,
      username: 'truenas_admin',
      secret: 'key',
    );
    const office = ServerInstance(
      id: 'b',
      name: 'Office',
      url: 'https://office.local',
      authMethod: AuthMethod.apiKey,
      username: 'truenas_admin',
      secret: 'key',
    );

    testWidgets('is hidden until there is a server to choose', (tester) async {
      await open(tester);
      expect(find.text('Default server'), findsNothing);
    });

    testWidgets('a single server is already the default', (tester) async {
      await open(tester, servers: [home]);
      expect(find.text('Default server'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('picks the server to open at start, or none', (tester) async {
      await open(tester, servers: [home, office]);
      expect(find.text('None, show the server list'), findsOneWidget);
      await choose(tester, 'Default server', 'Office');
      expect(container.read(settingsProvider).defaultServerId, 'b');
      expect((await saved()).defaultServerId, 'b');
      expect(find.text('Office'), findsOneWidget);

      await choose(tester, 'Default server', 'None, show the server list');
      expect((await saved()).defaultServerId, '');
    });
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

  group('alert notifications', () {
    late FakeAlertNotifier notifier;
    late FakeBackgroundScheduler scheduler;
    late MemoryStore alertStore;
    late List<Override> overrides;

    setUp(() {
      notifier = FakeAlertNotifier();
      scheduler = FakeBackgroundScheduler();
      alertStore = MemoryStore();
      overrides = [
        alertNotificationServiceProvider.overrideWithValue(
          AlertNotificationService(
            scheduler: scheduler,
            notifier: notifier,
            store: alertStore,
          ),
        ),
      ];
    });

    List<Override> on() => [
      ...overrides,
      initialSettingsProvider.overrideWithValue(
        const AppSettings(alertNotifications: true),
      ),
    ];

    testWidgets('live job progress has its own switch in Notifications', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Alert notifications'), findsNothing);
      await tester.tap(find.text('Live job progress'));
      await tester.pumpAndSettle();
      expect((await saved()).liveJobs, isFalse);
    });

    testWidgets(
      'says when the sideloaded copy lost its lock screen extension',
      (tester) async {
        await open(
          tester,
          overrides: [
            liveProgressProvider.overrideWithValue(
              FakeLiveProgress(liveSupport: LiveSupport.noExtension),
            ),
          ],
        );
        expect(
          find.textContaining('has no lock screen extension'),
          findsOneWidget,
        );
      },
    );

    testWidgets('says when Live Activities are off in iOS Settings', (
      tester,
    ) async {
      await open(
        tester,
        overrides: [
          liveProgressProvider.overrideWithValue(
            FakeLiveProgress(liveSupport: LiveSupport.disabled),
          ),
        ],
      );
      expect(find.textContaining('turned off for this app'), findsOneWidget);
    });

    testWidgets('alert types can be switched off one by one', (tester) async {
      await AlertKindCatalog(alertStore).record([
        const AlertKind(
          'PoolStatus',
          title: 'Pool Status',
          category: 'Storage',
        ),
        const AlertKind(
          'ScrubPaused',
          title: 'Scrub Paused',
          category: 'Storage',
        ),
        const AlertKind('MadeUp'),
      ]);
      await open(tester, overrides: on());
      expect(find.text('All on'), findsOneWidget);
      await tester.tap(find.text('Alert types'));
      await tester.pumpAndSettle();
      expect(find.text('Storage'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Made Up'), findsOneWidget);

      await tester.tap(find.text('Pool Status'));
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).mutedAlertKinds, {'PoolStatus'});
      expect((await saved()).mutedAlertKinds, {'PoolStatus'});

      await tester.enterText(find.byType(TextField), 'scrub');
      await tester.pumpAndSettle();
      expect(find.text('Pool Status'), findsNothing);
      expect(find.text('Scrub Paused'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('1 off'), findsOneWidget);
    });

    testWidgets('a kind muted before it was seen is listed and can come back', (
      tester,
    ) async {
      await open(
        tester,
        overrides: [
          ...overrides,
          initialSettingsProvider.overrideWithValue(
            const AppSettings(
              alertNotifications: true,
              mutedAlertKinds: {'SomethingNoisy'},
            ),
          ),
        ],
      );
      await tester.tap(find.text('Alert types'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Something Noisy'));
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).mutedAlertKinds, isEmpty);
    });

    testWidgets('say where the types come from while there are none', (
      tester,
    ) async {
      await open(tester, overrides: on());
      await tester.tap(find.text('Alert types'));
      await tester.pumpAndSettle();
      expect(find.textContaining('first background check'), findsOneWidget);
    });

    testWidgets('are not offered where the phone cannot run them', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Alert notifications'), findsNothing);
    });

    testWidgets('turn on after the phone allows notifications', (tester) async {
      await open(tester, overrides: overrides);
      expect(find.text('Notify for'), findsNothing);
      await tester.tap(find.text('Alert notifications'));
      await tester.pumpAndSettle();
      expect(notifier.permissionRequests, 1);
      expect(scheduler.scheduled, isTrue);
      expect((await saved()).alertNotifications, isTrue);
      expect(find.text('Critical alerts'), findsOneWidget);
    });

    testWidgets('stay off when notifications are refused', (tester) async {
      notifier.allowed = false;
      await open(tester, overrides: overrides);
      await tester.tap(find.text('Alert notifications'));
      await tester.pumpAndSettle();
      expect(scheduler.scheduled, isFalse);
      expect((await saved()).alertNotifications, isFalse);
      expect(find.textContaining('turned off for this app'), findsOneWidget);
    });

    testWidgets('stay off when the phone refuses the background task', (
      tester,
    ) async {
      scheduler.failWith = StateError('BGTaskScheduler refused');
      await open(tester, overrides: overrides);
      await tester.tap(find.text('Alert notifications'));
      await tester.pumpAndSettle();
      expect((await saved()).alertNotifications, isFalse);
      expect(find.textContaining('would not start'), findsOneWidget);
    });

    testWidgets('turn off and stop the check', (tester) async {
      await open(
        tester,
        overrides: [
          ...overrides,
          initialSettingsProvider.overrideWithValue(
            const AppSettings(alertNotifications: true, homeWidgets: false),
          ),
        ],
      );
      scheduler.scheduled = true;
      await tester.tap(find.text('Alert notifications'));
      await tester.pumpAndSettle();
      expect(scheduler.scheduled, isFalse);
      expect((await saved()).alertNotifications, isFalse);
    });

    testWidgets('turn off, but the widgets still need the check', (
      tester,
    ) async {
      await open(
        tester,
        overrides: [
          ...overrides,
          initialSettingsProvider.overrideWithValue(
            const AppSettings(alertNotifications: true),
          ),
        ],
      );
      scheduler.scheduled = true;
      await tester.tap(find.text('Alert notifications'));
      await tester.pumpAndSettle();
      expect(scheduler.scheduled, isTrue);
      expect((await saved()).alertNotifications, isFalse);
    });

    testWidgets('home screen widgets can be switched off', (tester) async {
      await open(tester, overrides: overrides);
      scheduler.scheduled = true;
      await tester.scrollUntilVisible(
        find.text('Home screen widgets'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Home screen widgets'));
      await tester.pumpAndSettle();
      expect((await saved()).homeWidgets, isFalse);
      expect(scheduler.scheduled, isFalse);
    });

    testWidgets('choose the lowest level that notifies', (tester) async {
      await open(
        tester,
        overrides: [
          ...overrides,
          initialSettingsProvider.overrideWithValue(
            const AppSettings(alertNotifications: true),
          ),
        ],
      );
      await choose(tester, 'Notify for', 'Warnings and critical');
      expect(
        container.read(settingsProvider).alertLevel,
        AlertSeverity.warning,
      );
      expect((await saved()).alertLevel, AlertSeverity.warning);
    });
  });

  group('app lock', () {
    testWidgets('is not offered on a phone that cannot ask', (tester) async {
      await open(
        tester,
        overrides: [
          biometricAuthProvider.overrideWithValue(
            FakeBiometricAuth(available: false),
          ),
        ],
      );
      expect(find.text('App lock'), findsNothing);
    });

    testWidgets('turns on after the phone confirms, and names Face ID', (
      tester,
    ) async {
      final auth = FakeBiometricAuth();
      await open(
        tester,
        overrides: [biometricAuthProvider.overrideWithValue(auth)],
      );
      expect(find.textContaining('Face ID'), findsOneWidget);
      await tester.tap(find.text('App lock'));
      await tester.pumpAndSettle();
      expect(auth.prompts, hasLength(1));
      expect((await saved()).appLock, isTrue);
    });

    testWidgets('stays off when the prompt is cancelled', (tester) async {
      final auth = FakeBiometricAuth(passes: false);
      await open(
        tester,
        overrides: [biometricAuthProvider.overrideWithValue(auth)],
      );
      await tester.tap(find.text('App lock'));
      await tester.pumpAndSettle();
      expect(auth.prompts, hasLength(1));
      expect((await saved()).appLock, isFalse);
    });

    testWidgets('asks again before turning off', (tester) async {
      final auth = FakeBiometricAuth(biometric: BiometricKind.fingerprint);
      await open(
        tester,
        overrides: [
          biometricAuthProvider.overrideWithValue(auth),
          initialSettingsProvider.overrideWithValue(
            const AppSettings(appLock: true),
          ),
        ],
      );
      expect(find.textContaining('fingerprint'), findsOneWidget);
      auth.passes = false;
      await tester.tap(find.text('App lock'));
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).appLock, isTrue);

      auth.passes = true;
      await tester.tap(find.text('App lock'));
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).appLock, isFalse);
    });

    testWidgets('can still be turned off once the phone cannot ask', (
      tester,
    ) async {
      final auth = FakeBiometricAuth(available: false);
      await open(
        tester,
        overrides: [
          biometricAuthProvider.overrideWithValue(auth),
          initialSettingsProvider.overrideWithValue(
            const AppSettings(appLock: true),
          ),
        ],
      );
      await tester.tap(find.text('App lock'));
      await tester.pumpAndSettle();
      expect(auth.prompts, isEmpty);
      expect(container.read(settingsProvider).appLock, isFalse);
    });
  });
}
