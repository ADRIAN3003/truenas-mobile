import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:truenas_mobile/app.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/settings/app_settings.dart';
import 'package:truenas_mobile/core/settings/settings_provider.dart';
import 'package:truenas_mobile/features/updates/updates_provider.dart';

import '../../support/memory_store.dart';
import '../../support/update_fakes.dart';

void main() {
  late MemoryStore settingsStore;
  late ProviderContainer container;

  setUp(() {
    settingsStore = MemoryStore();
    PackageInfo.setMockInitialValues(
      appName: 'TrueNAS Mobile',
      packageName: 'hu.adrian.truenasmobile',
      version: '0.1.3',
      buildNumber: '4',
      buildSignature: '',
    );
  });

  Future<void> launch(
    WidgetTester tester,
    FakeGitHub github, {
    AppSettings settings = const AppSettings(),
    bool autoCheck = true,
  }) async {
    container = ProviderContainer(
      overrides: [
        instanceRepositoryProvider.overrideWithValue(
          InstanceRepository(MemoryStore()),
        ),
        settingsRepositoryProvider.overrideWithValue(
          SettingsRepository(settingsStore),
        ),
        initialSettingsProvider.overrideWithValue(settings),
        updateCheckerProvider.overrideWithValue(github.checker),
        updateAutoCheckProvider.overrideWithValue(autoCheck),
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
  }

  final newer = FakeGitHub([
    releaseJson('v0.1.3'),
    releaseJson('v0.1.4', body: 'Added update checking'),
  ]);

  testWidgets('offers a newer release when the app opens', (tester) async {
    await launch(tester, newer);
    expect(find.text('Update available'), findsOneWidget);
    expect(
      find.text('Version 0.1.4 is available. You have 0.1.3.'),
      findsOneWidget,
    );
  });

  testWidgets('asks only for the latest release when the app opens', (
    tester,
  ) async {
    final github = FakeGitHub([releaseJson('v0.1.3'), releaseJson('v0.1.4')]);
    await launch(tester, github);
    expect(github.paths, ['/repos/ADRIAN3003/truenas-mobile/releases/latest']);
    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets('a repository without releases offers nothing', (tester) async {
    await launch(tester, FakeGitHub([]));
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('"Later" leaves everything as it was', (tester) async {
    await launch(tester, newer);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);
    expect(container.read(settingsProvider).skippedVersion, isNull);
  });

  testWidgets('"Skip this version" is remembered', (tester) async {
    await launch(tester, newer);
    await tester.tap(find.text('Skip this version'));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);
    expect(container.read(settingsProvider).skippedVersion, '0.1.4');
    final saved = await SettingsRepository(settingsStore).load();
    expect(saved.skippedVersion, '0.1.4');
  });

  testWidgets('"View update" opens the update screen', (tester) async {
    await launch(tester, newer);
    await tester.tap(find.text('View update'));
    await tester.pumpAndSettle();
    expect(find.text('Software update'), findsOneWidget);
    expect(find.text('Version 0.1.4 is available'), findsOneWidget);
    expect(find.textContaining('Added update checking'), findsOneWidget);
  });

  testWidgets('a skipped release is not offered again', (tester) async {
    await launch(
      tester,
      newer,
      settings: const AppSettings(skippedVersion: '0.1.4'),
    );
    expect(newer.requests, greaterThan(0), reason: 'it still looked');
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('a release newer than the skipped one is offered', (
    tester,
  ) async {
    await launch(
      tester,
      FakeGitHub([releaseJson('v0.1.4'), releaseJson('v0.1.5')]),
      settings: const AppSettings(skippedVersion: '0.1.4'),
    );
    expect(find.text('Update available'), findsOneWidget);
    expect(
      find.text('Version 0.1.5 is available. You have 0.1.3.'),
      findsOneWidget,
    );
  });

  testWidgets('says nothing when the app is up to date', (tester) async {
    await launch(tester, FakeGitHub([releaseJson('v0.1.3')]));
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('a failed check is silent', (tester) async {
    await launch(tester, FakeGitHub([], status: 500));
    expect(find.text('Update available'), findsNothing);
    expect(find.text('No servers yet'), findsOneWidget);
  });

  testWidgets('does not look when the setting is off', (tester) async {
    final github = FakeGitHub([releaseJson('v0.1.4')]);
    await launch(
      tester,
      github,
      settings: const AppSettings(checkForUpdates: false),
    );
    expect(github.requests, 0);
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('does not look unless the app turned the check on', (
    tester,
  ) async {
    final github = FakeGitHub([releaseJson('v0.1.4')]);
    await launch(tester, github, autoCheck: false);
    expect(github.requests, 0);
  });
}
