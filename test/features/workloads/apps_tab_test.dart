import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';
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

  Finder menuOf(String name) => find.descendant(
    of: find.widgetWithText(ListTile, name),
    matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
  );

  testWidgets('lists apps, VMs and containers with their state', (
    tester,
  ) async {
    await connect(tester);
    await tester.pumpWidget(wrap(AppsTab(session: session)));
    await settle(tester);

    expect(find.text('jellyfin'), findsOneWidget);
    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Virtual machines'), findsOneWidget);
    expect(find.text('8 vCPU · 8.0 GiB\nGaming'), findsOneWidget);
    expect(find.text('Containers'), findsOneWidget);
    expect(find.text('debian'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('starting a VM needs no confirmation; stopping an app does', (
    tester,
  ) async {
    await connect(tester);
    await tester.pumpWidget(wrap(AppsTab(session: session)));
    await settle(tester);

    await tester.tap(menuOf('win11'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start').last);
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    expect((server.vms.single['status'] as Map)['state'], 'RUNNING');

    await tester.tap(menuOf('jellyfin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop').last);
    await tester.pumpAndSettle();
    expect(find.text('Stop jellyfin?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Stop'));
    await settle(tester);
    expect(server.apps.single['state'], 'STOPPED');
    await disconnect(tester);
  });

  testWidgets('app screen upgrades after confirmation', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(AppsTab(session: session)));
    await settle(tester);

    await tester.tap(find.text('jellyfin'));
    await settle(tester);
    expect(find.text('http://nas:30013/'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Upgrade'));
    await tester.pumpAndSettle();
    expect(find.text('Upgrade jellyfin?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Upgrade').last);
    await settle(tester);
    expect(server.apps.single['upgrade_available'], isFalse);
    expect(find.widgetWithText(FilledButton, 'Upgrade'), findsNothing);
    await disconnect(tester);
  });

  testWidgets('apps show their catalog icon and Markdown notes', (
    tester,
  ) async {
    await connect(tester);
    final icon = 'http://127.0.0.1:${server.port}/icons/icon.png';
    final app = server.apps.firstWhere((a) => a['name'] == 'jellyfin');
    app['metadata'] = {'title': 'Jellyfin', 'icon': icon};
    app['notes'] =
        '# Jellyfin\n\nSign in as **admin** at [the web UI](https://nas/).';
    await tester.pumpWidget(wrap(AppsTab(session: session)));
    await settle(tester);

    bool showsIcon(Widget w) =>
        w is Image &&
        w.image is NetworkImage &&
        (w.image as NetworkImage).url == icon;
    expect(find.byWidgetPredicate(showsIcon), findsOneWidget);

    await tester.tap(find.text('jellyfin'));
    await settle(tester);
    expect(find.byWidgetPredicate(showsIcon), findsWidgets);
    await tester.scrollUntilVisible(
      find.byType(MarkdownBody),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
    expect(
      find.textContaining('the web UI', findRichText: true),
      findsOneWidget,
    );
    await disconnect(tester);
    // Let the icon download's idle HTTP connection time out.
    await tester.pump(const Duration(seconds: 16));
  });
}
