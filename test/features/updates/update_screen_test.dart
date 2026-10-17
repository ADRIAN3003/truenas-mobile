import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:truenas_mobile/core/settings/app_settings.dart';
import 'package:truenas_mobile/core/settings/settings_provider.dart';
import 'package:truenas_mobile/core/updates/apk_downloader.dart';
import 'package:truenas_mobile/features/updates/update_screen.dart';
import 'package:truenas_mobile/features/updates/updates_provider.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/memory_store.dart';
import '../../support/update_fakes.dart';

void main() {
  late FakeApkInstaller installer;
  late FakeApkDownloader downloader;
  late MemoryStore settingsStore;
  late ProviderContainer container;

  setUp(() {
    installer = FakeApkInstaller();
    downloader = FakeApkDownloader();
    settingsStore = MemoryStore();
    PackageInfo.setMockInitialValues(
      appName: 'TrueNAS Mobile',
      packageName: 'hu.adrian.truenasmobile',
      version: '0.1.3',
      buildNumber: '4',
      buildSignature: '',
    );
  });

  Future<void> open(
    WidgetTester tester,
    FakeGitHub github, {
    Widget screen = const UpdateScreen(),
  }) async {
    container = ProviderContainer(
      overrides: [
        updateCheckerProvider.overrideWithValue(github.checker),
        apkInstallerProvider.overrideWithValue(installer),
        apkDownloaderProvider.overrideWithValue(downloader),
        settingsRepositoryProvider.overrideWithValue(
          SettingsRepository(settingsStore),
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final newer = FakeGitHub([
    releaseJson('v0.1.3', body: 'Old notes'),
    releaseJson('v0.1.4', body: 'Added **update checking**'),
  ]);

  testWidgets('offers a newer release with its notes', (tester) async {
    await open(tester, newer);
    expect(find.text('Version 0.1.4 is available'), findsOneWidget);
    expect(find.text('You have version 0.1.3.'), findsOneWidget);
    expect(find.text('Download and install'), findsOneWidget);
    expect(find.text('Skip this version'), findsOneWidget);
    expect(find.text("What's new"), findsOneWidget);
    expect(find.textContaining('update checking'), findsOneWidget);
    expect(
      find.textContaining('Old notes'),
      findsNothing,
      reason: 'only the releases newer than the installed one',
    );
  });

  testWidgets('says so when the newest release is installed', (tester) async {
    await open(tester, FakeGitHub([releaseJson('v0.1.3', body: 'Old notes')]));
    expect(find.text("You're up to date"), findsOneWidget);
    expect(
      find.text('TrueNAS Mobile 0.1.3 is the newest release.'),
      findsOneWidget,
    );
    expect(find.text('Download and install'), findsNothing);
    expect(find.textContaining('Old notes'), findsOneWidget);
  });

  testWidgets('a repository without releases is not an error', (tester) async {
    await open(tester, FakeGitHub([]));
    expect(find.text('No releases have been published yet.'), findsOneWidget);
  });

  testWidgets('shows a failure and tries again', (tester) async {
    final github = FakeGitHub([], status: 500);
    await open(tester, github);
    expect(
      find.text(
        "Couldn't check for updates. Check your connection and try again.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(github.requests, 2);
  });

  testWidgets('a rate limit gets its own message', (tester) async {
    await open(tester, FakeGitHub([], status: 403));
    expect(
      find.text(
        'GitHub is limiting requests from this network. Try again later.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('downloads the APK for the phone and opens the installer', (
    tester,
  ) async {
    await open(tester, newer);
    await tester.tap(find.text('Download and install'));
    await tester.pumpAndSettle();
    expect(downloader.downloaded.single.name, contains('v0.1.4-arm64-v8a'));
    expect(installer.installed, [
      '/cache/updates/truenas-mobile-v0.1.4-arm64-v8a-release.apk',
    ]);
    expect(find.text('Download and install'), findsOneWidget);
  });

  testWidgets('asks to allow installs, then opens the settings page', (
    tester,
  ) async {
    installer.allowed = false;
    await open(tester, newer);
    await tester.tap(find.text('Download and install'));
    await tester.pumpAndSettle();
    expect(find.text('Allow installing updates'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(installer.settingsOpened, 1);
    expect(installer.installed, isEmpty);
    expect(downloader.downloaded, isEmpty);
  });

  testWidgets('declining the permission dialog changes nothing', (
    tester,
  ) async {
    installer.allowed = false;
    await open(tester, newer);
    await tester.tap(find.text('Download and install'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(installer.settingsOpened, 0);
    expect(find.text('Download and install'), findsOneWidget);
  });

  testWidgets('says when the release has no APK for the phone', (tester) async {
    await open(tester, FakeGitHub([releaseJson('v0.1.4', withApks: false)]));
    await tester.tap(find.text('Download and install'));
    await tester.pumpAndSettle();
    expect(find.textContaining('has no APK for your phone'), findsOneWidget);
    expect(installer.installed, isEmpty);
  });

  testWidgets('says when the download or the file is bad', (tester) async {
    await open(tester, newer);
    downloader.failWith = const ApkDownloadException(
      ApkDownloadFailure.network,
    );
    await tester.tap(find.text('Download and install'));
    await tester.pumpAndSettle();
    expect(find.textContaining('The download failed'), findsOneWidget);

    downloader.failWith = const ApkDownloadException(
      ApkDownloadFailure.damaged,
    );
    await tester.tap(find.text('Download and install'));
    await tester.pumpAndSettle();
    expect(find.textContaining('file is damaged'), findsOneWidget);
    expect(installer.installed, isEmpty);
  });

  testWidgets('skips a version and takes the skip back', (tester) async {
    await open(tester, newer);
    await tester.tap(find.text('Skip this version'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).skippedVersion, '0.1.4');
    expect(find.text('Stop skipping'), findsOneWidget);
    expect(find.textContaining('not offered when the app opens'), findsOne);
    expect(
      find.text('Download and install'),
      findsOneWidget,
      reason: 'a skipped release can still be installed by hand',
    );

    await tester.tap(find.text('Stop skipping'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).skippedVersion, isNull);
    expect(find.text('Skip this version'), findsOneWidget);
  });

  testWidgets(
    'elsewhere than Android opens the release page instead of installing',
    (tester) async {
      await open(tester, newer);
      expect(find.text('Open release page'), findsOneWidget);
      expect(find.text('Download and install'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('older release notes are collapsed until tapped', (tester) async {
    await open(tester, newer, screen: const ReleaseNotesScreen());
    // Every release is listed, but only the latest shows its notes.
    expect(find.text('v0.1.4'), findsOneWidget);
    expect(find.text('v0.1.3'), findsOneWidget);
    expect(find.textContaining('update checking'), findsOneWidget);
    expect(find.textContaining('Old notes'), findsNothing);

    await tester.tap(find.text('v0.1.3'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Old notes'), findsOneWidget);
    expect(find.textContaining('update checking'), findsOneWidget);

    // The latest can be folded away too.
    await tester.tap(find.text('v0.1.4'));
    await tester.pumpAndSettle();
    expect(find.textContaining('update checking'), findsNothing);
    expect(find.textContaining('Old notes'), findsOneWidget);
  });

  testWidgets('the update screen opens only the latest of several newer ones', (
    tester,
  ) async {
    await open(
      tester,
      FakeGitHub([
        releaseJson('v0.1.3', body: 'Installed notes'),
        releaseJson('v0.1.4', body: 'Middle notes'),
        releaseJson('v0.1.5', body: 'Newest notes'),
      ]),
    );
    expect(find.textContaining('Newest notes'), findsOneWidget);
    expect(find.text('v0.1.4'), findsOneWidget);
    expect(find.textContaining('Middle notes'), findsNothing);
    await tester.tap(find.text('v0.1.4'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Middle notes'), findsOneWidget);
  });

  testWidgets('release notes show pull request links as #id', (tester) async {
    await open(
      tester,
      FakeGitHub([
        releaseJson(
          'v0.1.4',
          body:
              'Alerts by @adrian in '
              'https://github.com/ADRIAN3003/truenas-mobile/pull/33',
        ),
      ]),
      screen: const ReleaseNotesScreen(),
    );
    expect(find.textContaining('#33', findRichText: true), findsOneWidget);
    expect(find.textContaining('github.com', findRichText: true), findsNothing);
  });

  testWidgets('a release without notes says so', (tester) async {
    await open(
      tester,
      FakeGitHub([releaseJson('v0.1.4', body: '')]),
      screen: const ReleaseNotesScreen(),
    );
    expect(find.text('This release has no notes.'), findsOneWidget);
  });
}
