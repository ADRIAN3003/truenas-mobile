import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';
import 'package:truenas_mobile/features/protection/protection_screen.dart';
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

  Finder menuOf(String name) => find.descendant(
    of: find.widgetWithText(ListTile, name),
    matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
  );

  testWidgets('shows each kind with its last result', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(ProtectionScreen(session: session)));
    await settle(tester);

    expect(find.text('Periodic snapshots'), findsOneWidget);
    expect(
      find.text('Every hour · Keep 2 weeks · with child datasets'),
      findsOneWidget,
    );
    expect(find.text('Succeeded'), findsOneWidget);
    expect(find.text('Replication'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('No route to host'), findsOneWidget);
    expect(find.text('Cloud sync'), findsOneWidget);
    expect(find.text('Running · 42%'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('TrueCloud backup'), 100);
    expect(find.text('No tasks yet.'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('runs, stops and enables tasks', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(ProtectionScreen(session: session)));
    await settle(tester);

    await tester.tap(menuOf('offsite'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run now'));
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    expect(server.calls.map((c) => c.$1), contains('replication.run'));

    await tester.tap(menuOf('Photos to B2'));
    await tester.pumpAndSettle();
    expect(find.text('Run now'), findsNothing);
    await tester.tap(find.text('Stop'));
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    expect(server.calls.map((c) => c.$1), contains('cloudsync.abort'));

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Photos to B2'),
        matching: find.byType(Switch),
      ),
    );
    await settle(tester);
    expect(server.protection['cloudsync']!.single['enabled'], isTrue);
    await disconnect(tester);
  });

  testWidgets('adds and deletes snapshot tasks', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(ProtectionScreen(session: session)));
    await settle(tester);

    await tester.tap(find.text('Add snapshot task'));
    await settle(tester);
    expect(find.text('Every day at midnight'), findsOneWidget);
    await tester.tap(find.text('Create'));
    await settle(tester);
    final created =
        server.calls
                .lastWhere((c) => c.$1 == 'pool.snapshottask.create')
                .$2
                .single
            as Map;
    expect(created['dataset'], 'tank');
    expect(created['lifetime_value'], 2);
    expect(created['lifetime_unit'], 'WEEK');

    await tester.tap(menuOf('tank/media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Delete the task for tank/media?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await settle(tester);
    expect(server.protection['pool.snapshottask']!.map((t) => t['dataset']), [
      'tank',
    ]);
    await disconnect(tester);
  });
}
