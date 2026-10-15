import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';
import 'package:truenas_mobile/features/shell/shell_screen.dart';
import 'package:truenas_mobile/features/workloads/apps_tab.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_truenas_server.dart';

void main() {
  late FakeTrueNasServer server;
  late TrueNasSession session;

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  setUp(() => HttpOverrides.global = null);

  Future<void> connect(WidgetTester tester, {bool legacy = false}) async {
    await tester.runAsync(() async {
      server = await FakeTrueNasServer.start();
      server.legacy = legacy;
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

  Future<void> openShellFrom(WidgetTester tester, String name) async {
    await tester.pumpWidget(wrap(AppsTab(session: session)));
    await settle(tester);
    final menu = find.descendant(
      of: find.widgetWithText(ListTile, name),
      matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
    );
    await tester.scrollUntilVisible(menu, 100);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shell'));
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
  }

  testWidgets('app shell opens in the app container', (tester) async {
    await connect(tester);
    await openShellFrom(tester, 'jellyfin');
    expect(find.byType(ShellScreen), findsOneWidget);
    expect(server.shellOptions, {
      'app_name': 'jellyfin',
      'container_id': 'c0ffee',
    });
    await disconnect(tester);
  });

  testWidgets('VM shell opens its console', (tester) async {
    await connect(tester);
    (server.vms.single['status'] as Map)['state'] = 'RUNNING';
    await openShellFrom(tester, 'win11');
    expect(server.shellOptions, {'vm_id': 1});
    await disconnect(tester);
  });

  testWidgets('container shell uses the server container system', (
    tester,
  ) async {
    await connect(tester, legacy: true);
    await openShellFrom(tester, 'debian');
    expect(server.shellOptions, {'virt_instance_id': 'debian'});
    await disconnect(tester);
  });
}
