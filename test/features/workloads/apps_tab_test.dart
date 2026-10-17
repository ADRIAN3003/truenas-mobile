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

  /// Like [settle] without waiting for animations: the spinners of apps that
  /// wait for the server never stop.
  Future<void> spin(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Lets the tab's poll timer fire once and its requests come back.
  Future<void> pollServer(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await spin(tester);
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

  group('Update all', () {
    Map<String, dynamic> extraApp(String name, {required bool update}) => {
      'name': name,
      'id': name,
      'state': 'RUNNING',
      'human_version': '1.0.0',
      'version': '1.0.0',
      'latest_version': update ? '1.1.0' : '1.0.0',
      'upgrade_available': update,
      'image_updates_available': false,
      'custom_app': false,
      'metadata': {'title': name[0].toUpperCase() + name.substring(1)},
      'active_workloads': {'containers': 1, 'images': <String>[]},
      'portals': <String, String>{},
      'notes': null,
    };

    testWidgets('lists every app it will update, then updates them', (
      tester,
    ) async {
      await connect(tester);
      server.apps
        ..add(extraApp('immich', update: true))
        ..add(extraApp('plex', update: false));
      await tester.pumpWidget(wrap(AppsTab(session: session)));
      await settle(tester);

      expect(find.text('2 apps have updates'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Update all'));
      await tester.pumpAndSettle();

      // The dialog names both apps with their versions, and leaves out the
      // one that is up to date.
      expect(find.text('Update 2 apps?'), findsOneWidget);
      expect(find.text('Jellyfin'), findsOneWidget);
      expect(find.text('1.2.3 → 1.2.4'), findsOneWidget);
      expect(find.text('Immich'), findsOneWidget);
      expect(find.text('1.0.0 → 1.1.0'), findsOneWidget);
      expect(find.text('Plex'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Update all').last);
      await settle(tester);
      await pollServer(tester);

      // One job on the server for both apps, not a call per app from the phone.
      expect(server.bulkCalls, hasLength(1));
      expect(server.bulkCalls.single.$1, 'app.upgrade');
      expect(server.bulkCalls.single.$2, [
        ['immich'],
        ['jellyfin'],
      ]);
      expect(server.calls.map((c) => c.$1), isNot(contains('app.upgrade')));
      expect(
        server.apps.map((a) => a['upgrade_available']),
        everyElement(isFalse),
      );
      expect(find.text('2 apps updated'), findsOneWidget);
      // Nothing left to update, so the card goes away.
      expect(find.text('Update all'), findsNothing);
      await disconnect(tester);
    });

    testWidgets('keeps going on the server when the screen is left', (
      tester,
    ) async {
      await connect(tester);
      server.apps.add(extraApp('immich', update: true));
      server.holdBulkUpgrades = true;
      await tester.pumpWidget(wrap(AppsTab(session: session)));
      await settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Update all'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Update all').last);
      await spin(tester);
      expect(find.text('Updating on the server: 0 of 2 done'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Update all'), findsNothing);

      // The user leaves; the job is not cancelled.
      await tester.pumpWidget(const SizedBox());
      expect(
        server.apps.map((a) => a['upgrade_available']),
        everyElement(true),
      );

      // Back on the tab the same job is found and followed.
      await tester.pumpWidget(wrap(AppsTab(session: session)));
      await spin(tester);
      expect(find.text('Updating on the server: 0 of 2 done'), findsOneWidget);
      expect(server.bulkCalls, hasLength(1));

      server.finishBulkUpgrades();
      await pollServer(tester);
      expect(find.text('2 apps updated'), findsOneWidget);
      expect(find.textContaining('Updating on the server'), findsNothing);
      await disconnect(tester);
    });

    testWidgets('cancelling updates nothing', (tester) async {
      await connect(tester);
      await tester.pumpWidget(wrap(AppsTab(session: session)));
      await settle(tester);

      expect(find.text('1 app has an update'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Update all'));
      await tester.pumpAndSettle();
      expect(find.text('Update 1 app?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(server.bulkCalls, isEmpty);
      expect(server.apps.single['upgrade_available'], isTrue);
      expect(find.text('Update all'), findsOneWidget);
      await disconnect(tester);
    });

    testWidgets('an app that fails does not stop the others', (tester) async {
      await connect(tester);
      server.apps.add(extraApp('immich', update: true));
      server.failingUpgrades.add('jellyfin');
      await tester.pumpWidget(wrap(AppsTab(session: session)));
      await settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Update all'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Update all').last);
      await settle(tester);
      await pollServer(tester);

      expect(server.apps[0]['upgrade_available'], isTrue);
      expect(server.apps[1]['upgrade_available'], isFalse);
      expect(
        find.text('1 of 2 apps updated. Not updated: jellyfin'),
        findsOneWidget,
      );
      // jellyfin can still be updated, so the card stays.
      expect(find.text('1 app has an update'), findsOneWidget);
      await disconnect(tester);
    });

    testWidgets('is not offered when every app is up to date', (tester) async {
      await connect(tester);
      server.apps.single['upgrade_available'] = false;
      await tester.pumpWidget(wrap(AppsTab(session: session)));
      await settle(tester);

      expect(find.text('Update all'), findsNothing);
      await disconnect(tester);
    });
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
