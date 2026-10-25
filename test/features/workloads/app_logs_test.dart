import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';
import 'package:truenas_mobile/features/workloads/app_logs_screen.dart';
import 'package:truenas_mobile/features/workloads/apps_tab.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_truenas_server.dart';

void main() {
  late FakeTrueNasServer server;
  late TrueNasSession session;

  Widget wrap(Widget child) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  setUp(() => HttpOverrides.global = null);

  Future<void> connect(
    WidgetTester tester, {
    bool withArgsInName = false,
  }) async {
    await tester.runAsync(() async {
      server = await FakeTrueNasServer.start();
      server.logCollectionWithArgs = withArgsInName;
      final (s, _) = await connectToInstance(
        ServerInstance(
          id: '1',
          name: 'Home',
          url: 'http://127.0.0.1:${server.port}',
          authMethod: AuthMethod.password,
          username: 'truenas_admin',
          secret: 'secret',
        ),
        confirmCertificate: (_) async => false,
        askOtp: () async => null,
      );
      session = s;
    });
  }

  Future<void> disconnect(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await session.close();
      await server.close();
    });
  }

  Future<void> openLogsFrom(WidgetTester tester, String name) async {
    await tester.pumpWidget(wrap(AppsTab(session: session)));
    await settle(tester);
    final menu = find.descendant(
      of: find.widgetWithText(ListTile, name),
      matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
    );
    await tester.scrollUntilVisible(menu, 100);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logs'));
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
  }

  testWidgets('shows the log of the app container without a shell', (
    tester,
  ) async {
    await connect(tester);
    await openLogsFrom(tester, 'jellyfin');
    expect(find.byType(AppLogsScreen), findsOneWidget);
    expect(find.text('jellyfin · jellyfin'), findsOneWidget);
    expect(server.subscriptions.last, startsWith('app.container_log_follow:'));
    expect(server.subscriptions.last, contains('"app_name":"jellyfin"'));
    expect(server.subscriptions.last, contains('"container_id":"c0ffee"'));
    expect(server.subscriptions.last, contains('"tail_lines":500'));
    expect(find.textContaining('server started'), findsOneWidget);
    // Colour codes are dropped.
    expect(find.text('2026-10-25T20:00:03Z ERROR disk not found'), findsOne);
    await disconnect(tester);
  });

  testWidgets('follows new lines and accepts events named with arguments', (
    tester,
  ) async {
    await connect(tester, withArgsInName: true);
    await openLogsFrom(tester, 'jellyfin');
    await tester.runAsync(() async => server.pushLogLine('later line'));
    await settle(tester);
    expect(find.text('later line'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('filters lines and copies what is shown', (tester) async {
    await connect(tester);
    await openLogsFrom(tester, 'jellyfin');
    await tester.tap(find.byTooltip('Filter lines'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'warn');
    await tester.pump();
    expect(find.textContaining('cache is cold'), findsOneWidget);
    expect(find.textContaining('server started'), findsNothing);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    await tester.tap(find.byTooltip('Copy'));
    await tester.pump();
    expect(copied, '2026-10-25T20:00:02Z WARN cache is cold');
    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pump();
    expect(find.text('No lines match.'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('the tail length can be changed', (tester) async {
    await connect(tester);
    await openLogsFrom(tester, 'jellyfin');
    await tester.tap(
      find.descendant(
        of: find.byType(AppLogsScreen),
        matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 2000 lines'));
    await tester.pump();
    await settle(tester);
    expect(server.subscriptions.last, contains('"tail_lines":2000'));
    expect(find.textContaining('server started'), findsOneWidget);
    await disconnect(tester);
  });
}
