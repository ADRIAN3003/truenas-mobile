import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';
import 'package:truenas_mobile/features/server/more_tab.dart';
import 'package:truenas_mobile/features/system/api_keys_screen.dart';
import 'package:truenas_mobile/features/system/network_screen.dart';
import 'package:truenas_mobile/features/system/updates_screen.dart';
import 'package:truenas_mobile/features/system/users_screen.dart';
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
    await tester.runAsync(() async {
      await session.close();
      await server.close();
    });
  }

  testWidgets('more tab lists accounts, system and activity', (tester) async {
    await connect(tester);
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: MoreTab(session: session, serverName: 'Home'),
        ),
      ),
    );
    await settle(tester);
    for (final label in [
      'Users',
      'API keys',
      'Network',
      'Certificates',
      'Updates',
      'Alerts',
    ]) {
      await tester.scrollUntilVisible(find.text(label), 100);
      expect(find.text(label), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text('Shut down server'), 100);
    await tester.tap(find.text('Restart server'));
    await tester.pumpAndSettle();
    expect(find.text('Restart Home?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(server.calls.where((c) => c.$1 == 'system.reboot'), isEmpty);
    await disconnect(tester);
  });

  testWidgets('adds a user', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(UsersScreen(session: session)));
    await settle(tester);
    expect(find.text('alice'), findsOneWidget);
    expect(find.text('root'), findsNothing);

    await tester.tap(find.text('Add user'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'Bad Name',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'pw',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Use lowercase'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'bob',
    );
    await tester.tap(find.text('Create'));
    await settle(tester);
    expect(server.users.map((u) => u['username']), contains('bob'));
    expect(find.text('bob'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('shows a new API key once with a copy button', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(ApiKeysScreen(session: session)));
    await settle(tester);
    expect(find.text('home-assistant'), findsOneWidget);

    await tester.tap(find.text('Add API key'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Key name'), 'ci');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await settle(tester);
    expect(find.text('Copy your API key'), findsOneWidget);
    expect(find.text('2-SECRETKEY'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('ci'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('network shows gateway, DNS and interfaces', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(NetworkScreen(session: session)));
    await settle(tester);
    expect(find.text('192.168.1.1'), findsOneWidget);
    expect(find.text('1.1.1.1\n9.9.9.9'), findsOneWidget);
    expect(find.text('enp1s0 · Onboard'), findsOneWidget);
    expect(find.text('Link up'), findsOneWidget);
    expect(find.text('Link down'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('certificates flag expired ones', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(CertificatesScreen(session: session)));
    await settle(tester);
    expect(find.text('truenas_default'), findsOneWidget);
    expect(find.text('Valid until Tue Oct 13 08:00:00 2026'), findsOneWidget);
    expect(find.text('Expired'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('installs an update after confirming', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(UpdatesScreen(session: session)));
    await settle(tester);
    expect(find.text('Running 25.10.7'), findsOneWidget);
    expect(find.text('25.10.8 is available'), findsOneWidget);
    expect(find.text('Running now'), findsOneWidget);

    await tester.tap(find.text('Install and restart'));
    await tester.pumpAndSettle();
    expect(find.text('Install 25.10.8?'), findsOneWidget);
    await tester.tap(find.text('Install and restart').last);
    await settle(tester);
    expect(server.calls.map((c) => c.$1), contains('update.run'));
    await disconnect(tester);
  });

  testWidgets('installs an update without restarting', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(UpdatesScreen(session: session)));
    await settle(tester);
    expect(find.text('Download size: 1.0 GiB'), findsOneWidget);

    await tester.tap(find.text('Install, restart later'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install, restart later').last);
    await settle(tester);
    final run = server.calls.lastWhere((c) => c.$1 == 'update.run');
    expect(run.$2.single, {'reboot': false});
    await disconnect(tester);
  });

  testWidgets('offers a restart once an update is installed', (tester) async {
    await connect(tester);
    server.rebootRequired = true;
    await tester.pumpWidget(
      wrap(UpdatesScreen(session: session, serverName: 'Home')),
    );
    await settle(tester);
    expect(find.text('An update is installed. Restart to finish.'), findsOne);
    expect(find.text('Install and restart'), findsNothing);

    await tester.tap(find.text('Restart now'));
    await tester.pumpAndSettle();
    expect(find.text('Restart Home?'), findsOneWidget);
    await tester.tap(find.text('Restart').last);
    await settle(tester);
    expect(server.calls.map((c) => c.$1), contains('system.reboot'));
    await disconnect(tester);
  });

  testWidgets('activates an older boot environment', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(UpdatesScreen(session: session)));
    await settle(tester);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, '25.10.6'),
        matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use on next boot'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Boot 25.10.6 next time?'), findsOneWidget);
    await tester.tap(find.text('Use on next boot'));
    await settle(tester);
    expect(
      server.bootEnvironments.firstWhere(
        (e) => e['id'] == '25.10.6',
      )['activated'],
      isTrue,
    );
    expect(find.text('Used on next boot'), findsOneWidget);
    await disconnect(tester);
  });
}
