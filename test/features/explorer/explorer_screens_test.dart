import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';
import 'package:truenas_mobile/features/explorer/api_explorer_screen.dart';
import 'package:truenas_mobile/features/shell/shell_screen.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_truenas_server.dart';

void main() {
  late FakeTrueNasServer server;
  late TrueNasSession session;

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  setUp(() => HttpOverrides.global = null);

  Future<void> connect(WidgetTester tester) async {
    await tester.runAsync(() async {
      server = await FakeTrueNasServer.start();
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
    // Let the shell socket finish closing so its timers are cancelled.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await session.close();
      await server.close();
    });
  }

  testWidgets('browses namespaces and searches methods', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(ApiExplorerScreen(session: session)));
    await settle(tester);

    expect(find.text('pool'), findsOneWidget);
    expect(find.text('test'), findsOneWidget);
    expect(find.text('2 methods'), findsOneWidget);

    await tester.tap(find.text('test'));
    await tester.pumpAndSettle();
    expect(find.text('fail'), findsOneWidget);
    expect(find.text('job'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'pools');
    await tester.pump();
    expect(find.text('pool.query'), findsOneWidget);
    expect(find.text('Query pools.'), findsOneWidget);
    expect(find.text('system.info'), findsNothing);
    await tester.enterText(find.byType(SearchBar), 'zzz');
    await tester.pump();
    expect(find.text('No methods match.'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('read-only methods run without confirmation', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(ApiExplorerScreen(session: session)));
    await settle(tester);
    await tester.enterText(find.byType(SearchBar), 'system.info');
    await tester.pump();
    await tester.tap(find.widgetWithText(ListTile, 'system.info'));
    await tester.pumpAndSettle();

    expect(find.text('This method takes no parameters.'), findsOneWidget);
    expect(find.text('Roles: READONLY_ADMIN'), findsOneWidget);
    await tester.tap(find.text('Run'));
    await settle(tester);
    expect(find.text('Result'), findsOneWidget);
    expect(find.textContaining('"hostname": "nas"'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('builds a form and confirms before changing things', (
    tester,
  ) async {
    await connect(tester);
    await tester.pumpWidget(wrap(ApiExplorerScreen(session: session)));
    await settle(tester);
    await tester.enterText(find.byType(SearchBar), 'user.update');
    await tester.pump();
    await tester.tap(find.widgetWithText(ListTile, 'user.update'));
    await tester.pumpAndSettle();

    final id = find.widgetWithText(TextFormField, 'id');
    expect(id, findsOneWidget);
    expect(find.textContaining('"locked": false'), findsOneWidget);

    await tester.enterText(id, 'abc');
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number'), findsOneWidget);

    await tester.enterText(id, '70');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'user_update'),
      '{"locked": true',
    );
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not valid JSON'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'user_update'),
      '{"locked": true}',
    );
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    expect(find.text('Run user.update?'), findsOneWidget);
    await tester.tap(find.text('Run').last);
    await settle(tester);
    expect(server.calls.lastWhere((c) => c.$1 == 'user.update').$2, [
      70,
      {'locked': true},
    ]);
    expect(server.users.firstWhere((u) => u['id'] == 70)['locked'], isTrue);
    await disconnect(tester);
  });

  testWidgets('optional params are only sent when ticked; errors show', (
    tester,
  ) async {
    await connect(tester);
    await tester.pumpWidget(wrap(ApiExplorerScreen(session: session)));
    await settle(tester);
    await tester.enterText(find.byType(SearchBar), 'test.');
    await tester.pump();
    await tester.tap(find.text('test.job'));
    await tester.pumpAndSettle();

    expect(find.text('"FAST"'), findsOneWidget);
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run').last);
    await settle(tester);
    expect(server.calls.lastWhere((c) => c.$1 == 'test.job').$2, ['FAST']);
    expect(find.text('true'), findsOneWidget);

    await tester.tap(find.text('Send force'));
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run').last);
    await settle(tester);
    expect(server.calls.lastWhere((c) => c.$1 == 'test.job').$2, [
      'FAST',
      true,
    ]);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('test.fail'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'name'), 'x');
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run').last);
    await settle(tester);
    expect(find.textContaining('Bad name'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('shell connects and sends special keys', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(ShellScreen(session: session)));
    await settle(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('The shell has ended.'), findsNothing);

    await tester.tap(find.text('Esc'));
    await tester.tap(find.text('Ctrl+C'));
    await settle(tester);
    expect(server.shellInput.toString(), '\x1b\x03');
    expect(server.shellResizes, isNotEmpty);
    await disconnect(tester);
  });

  testWidgets('shell explains a refusal and offers to retry', (tester) async {
    await connect(tester);
    server.shellDenied = true;
    await tester.pumpWidget(wrap(ShellScreen(session: session)));
    await settle(tester);
    expect(find.textContaining('Invalid token'), findsOneWidget);

    server.shellDenied = false;
    await tester.tap(find.text('Start a new shell'));
    await settle(tester);
    expect(find.textContaining('Invalid token'), findsNothing);
    await disconnect(tester);
  });
}
