import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:truenas_mobile/core/logging/app_log.dart';
import 'package:truenas_mobile/core/logging/log_providers.dart';
import 'package:truenas_mobile/features/settings/log_screen.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';
import 'package:truenas_mobile/shared/theme.dart';

import '../../support/log_fakes.dart';

void main() {
  late AppLog log;
  late FakeLogSharer sharer;
  String? clipboard;

  setUp(() {
    log = AppLog();
    sharer = FakeLogSharer();
    clipboard = null;
    PackageInfo.setMockInitialValues(
      appName: 'TrueNAS Mobile',
      packageName: 'hu.adrian.truenasmobile',
      version: '0.1.5',
      buildNumber: '6',
      buildSignature: '',
    );
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLogProvider.overrideWithValue(log),
          logSharerProvider.overrideWithValue(sharer),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LogScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('says so when nothing was recorded', (tester) async {
    await open(tester);
    expect(find.text('Nothing recorded'), findsOneWidget);
    final copy = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.copy_rounded),
    );
    expect(copy.onPressed, isNull);
  });

  testWidgets('lists the entries newest first', (tester) async {
    log.warning('rpc', 'first failure');
    log.error('flutter', 'second failure', StackTrace.fromString('#0 here'));
    await open(tester);
    expect(find.text('Nothing recorded'), findsNothing);
    final first = tester.getTopLeft(find.text('second failure')).dy;
    final second = tester.getTopLeft(find.text('first failure')).dy;
    expect(first, lessThan(second));

    // The stack trace opens on tap.
    expect(find.text('#0 here'), findsNothing);
    await tester.tap(find.text('second failure'));
    await tester.pumpAndSettle();
    expect(find.text('#0 here'), findsOneWidget);
  });

  testWidgets('copies the log with the app version on top', (tester) async {
    log.warning('rpc', 'pool.query failed');
    await open(tester);
    await tester.tap(find.byTooltip('Copy'));
    await tester.pumpAndSettle();
    expect(clipboard, startsWith('TrueNAS Mobile log\nApp: 0.1.5 (6)\n'));
    expect(clipboard, contains('WARNING [rpc] pool.query failed'));
    expect(find.text('Log copied'), findsOneWidget);
  });

  testWidgets('shares the same text through the share sheet', (tester) async {
    log.warning('rpc', 'pool.query failed');
    await open(tester);
    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    expect(sharer.shared.single, contains('WARNING [rpc] pool.query failed'));
  });

  testWidgets('tells when the share sheet fails', (tester) async {
    log.warning('rpc', 'x failed');
    sharer.fail = true;
    await open(tester);
    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    expect(find.text('Could not share the log'), findsOneWidget);
  });

  testWidgets('clearing asks first, then empties the log', (tester) async {
    log.warning('rpc', 'x failed');
    await open(tester);
    await tester.tap(find.byTooltip('Clear log'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(log.entries, hasLength(1));

    await tester.tap(find.byTooltip('Clear log'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(log.entries, isEmpty);
    expect(find.text('Nothing recorded'), findsOneWidget);
  });
}
