import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';
import 'package:truenas_mobile/features/storage/datasets_screen.dart';
import 'package:truenas_mobile/features/storage/pool_screen.dart';
import 'package:truenas_mobile/features/storage/storage_tab.dart';
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
    for (var i = 0; i < 5; i++) {
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

  testWidgets('storage tab lists pools and disks entry', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(Scaffold(body: StorageTab(session: session))));
    await settle(tester);

    expect(find.text('tank'), findsOneWidget);
    expect(find.text('Disks'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('pool screen shows scrub state and topology', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(PoolScreen(session: session, poolId: 1)));
    await settle(tester);

    expect(find.text('Start scrub'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('sdb'), 200);
    expect(find.text('sda'), findsOneWidget);
    expect(find.text('DEGRADED'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('datasets can be created', (tester) async {
    await connect(tester);
    await tester.pumpWidget(
      wrap(DatasetsScreen(session: session, pool: 'tank')),
    );
    await settle(tester);

    expect(find.text('tank'), findsOneWidget);
    expect(find.text('media'), findsOneWidget);
    expect(find.text('vm'), findsOneWidget);

    await tester.tap(find.text('Create dataset'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('datasetName')), 'bad name');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Use letters, numbers, - _ . and : only'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('datasetName')), 'backups');
    await tester.tap(find.text('Create'));
    await settle(tester);
    expect(server.datasets.map((d) => d['id']), contains('tank/backups'));
    expect(find.text('backups'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('snapshots list and delete; dataset delete needs its name', (
    tester,
  ) async {
    await connect(tester);
    final dataset = (await tester.runAsync(
      () => session.storage.datasets('tank'),
    ))!.firstWhere((d) => d.id == 'tank/media');
    await tester.pumpWidget(
      wrap(DatasetScreen(session: session, dataset: dataset)),
    );
    await settle(tester);

    expect(find.text('/mnt/tank/media'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('auto-1'), 200);
    expect(find.text('auto-2'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
    expect(server.snapshots.map((s) => s['id']), ['tank/media@auto-2']);

    await tester.tap(find.byTooltip('Delete dataset'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Delete');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'tank/media',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await disconnect(tester);
  });
}
