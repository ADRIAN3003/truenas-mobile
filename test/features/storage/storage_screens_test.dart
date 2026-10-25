import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/models/storage.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';
import 'package:truenas_mobile/features/storage/datasets_screen.dart';
import 'package:truenas_mobile/features/storage/disks_screen.dart';
import 'package:truenas_mobile/features/storage/disk_screen.dart';
import 'package:truenas_mobile/features/storage/pool_screen.dart';
import 'package:truenas_mobile/features/storage/snapshots_screen.dart';
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

  testWidgets('a disk opens with its temperature and self-test log', (
    tester,
  ) async {
    await connect(tester);
    await tester.pumpWidget(wrap(DisksScreen(session: session)));
    await settle(tester);

    await tester.tap(find.textContaining('sda'));
    await settle(tester);

    expect(find.text('34 °C'), findsOneWidget);
    expect(find.text('Last self-test passed'), findsOneWidget);
    expect(find.text('Short offline'), findsOneWidget);
    expect(find.text('Extended offline'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.textContaining('First error at block 4096'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('a self-test can be started from the disk screen', (
    tester,
  ) async {
    await connect(tester);
    await tester.pumpWidget(
      wrap(
        DiskScreen(
          session: session,
          disk: const Disk(
            name: 'sda',
            identifier: '{serial}S1',
            size: 4000000000000,
            isSsd: false,
          ),
        ),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Run a test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Long · hours'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('Long test started on sda'), findsOneWidget);
    expect(
      server.calls.any(
        (c) =>
            c.$1 == 'smart.test.manual_test' &&
            (c.$2.first as List).first['type'] == 'LONG',
      ),
      isTrue,
    );
    // Let the delayed refresh finish before the screen goes.
    await tester.pump(const Duration(seconds: 3));
    await disconnect(tester);
  });

  testWidgets('a running self-test shows progress and blocks a new one', (
    tester,
  ) async {
    await connect(tester);
    server.smartProgress = 40;
    await tester.pumpWidget(
      wrap(
        DiskScreen(
          session: session,
          disk: const Disk(name: 'sda', size: 4000000000000, isSsd: false),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('40% done'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Run a test'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button.onPressed, isNull);
    await disconnect(tester);
  });

  testWidgets('the disk screen copes with a server without smart tests', (
    tester,
  ) async {
    await connect(tester);
    server.smart = false;
    await tester.pumpWidget(
      wrap(
        DiskScreen(
          session: session,
          disk: const Disk(name: 'sda', size: 4000000000000, isSsd: false),
        ),
      ),
    );
    await settle(tester);

    expect(
      find.text('This server does not report S.M.A.R.T. test results.'),
      findsOneWidget,
    );
    expect(find.text('Run a test'), findsNothing);
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

  Future<void> openSnapshots(WidgetTester tester) async {
    await connect(tester);
    final dataset = (await tester.runAsync(
      () => session.storage.datasets('tank'),
    ))!.firstWhere((d) => d.id == 'tank/media');
    await tester.pumpWidget(
      wrap(DatasetScreen(session: session, dataset: dataset)),
    );
    await settle(tester);
    await tester.tap(find.text('Browse, roll back and clone'));
    await settle(tester);
  }

  Future<void> pickMenu(WidgetTester tester, int row, String item) async {
    await tester.tap(find.byType(PopupMenuButton<String>).at(row));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets('dataset delete needs its name', (tester) async {
    await connect(tester);
    final dataset = (await tester.runAsync(
      () => session.storage.datasets('tank'),
    ))!.firstWhere((d) => d.id == 'tank/media');
    await tester.pumpWidget(
      wrap(DatasetScreen(session: session, dataset: dataset)),
    );
    await settle(tester);

    expect(find.text('/mnt/tank/media'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete dataset'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Delete');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, 'tank/media');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await disconnect(tester);
  });

  testWidgets('snapshot browser searches, sorts and deletes', (tester) async {
    await openSnapshots(tester);

    expect(find.text('2 snapshots · 2.0 KiB used'), findsOneWidget);
    // Newest first.
    expect(
      tester.getTopLeft(find.text('auto-2')).dy,
      lessThan(tester.getTopLeft(find.text('auto-1')).dy),
    );
    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oldest first'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('auto-1')).dy,
      lessThan(tester.getTopLeft(find.text('auto-2')).dy),
    );

    await tester.enterText(find.byKey(const Key('snapshotSearch')), 'auto-1');
    await tester.pump();
    expect(find.text('auto-2'), findsNothing);
    await tester.enterText(find.byKey(const Key('snapshotSearch')), 'nope');
    await tester.pump();
    expect(find.text('No snapshots match'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('snapshotSearch')), 'auto-1');
    await tester.pump();

    await pickMenu(tester, 0, 'Delete');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
    expect(server.snapshots.map((s) => s['id']), ['tank/media@auto-2']);
    await disconnect(tester);
  });

  testWidgets('rollback names the newer snapshots it destroys', (tester) async {
    await openSnapshots(tester);

    // The older snapshot is the second row.
    await pickMenu(tester, 1, 'Roll back');
    expect(find.text('This newer snapshot will be destroyed:'), findsOneWidget);
    expect(find.text('• auto-2'), findsOneWidget);
    final confirm = find.widgetWithText(FilledButton, 'Roll back');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, 'media');
    await tester.pump();
    await tester.tap(find.byKey(const Key('rollbackForce')));
    await tester.pump();
    await tester.tap(confirm);
    await settle(tester);

    expect(server.snapshots.map((s) => s['id']), ['tank/media@auto-1']);
    final call = server.calls.firstWhere(
      (c) => c.$1 == '${server.snapshotService}.rollback',
    );
    expect(call.$2, [
      'tank/media@auto-1',
      {'recursive': true, 'force': true},
    ]);
    await disconnect(tester);
  });

  testWidgets('rolling back to the newest snapshot destroys nothing', (
    tester,
  ) async {
    await openSnapshots(tester);

    await pickMenu(tester, 0, 'Roll back');
    expect(find.textContaining('will be destroyed'), findsNothing);
    await tester.enterText(find.byType(TextField).last, 'media');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Roll back'));
    await settle(tester);

    final call = server.calls.firstWhere(
      (c) => c.$1 == '${server.snapshotService}.rollback',
    );
    expect(call.$2, [
      'tank/media@auto-2',
      {'recursive': false},
    ]);
    expect(server.snapshots, hasLength(2));
    await disconnect(tester);
  });

  testWidgets('a snapshot can be cloned into the same pool', (tester) async {
    await openSnapshots(tester);

    await pickMenu(tester, 0, 'Clone');
    await tester.enterText(find.byKey(const Key('cloneTarget')), 'other/copy');
    await tester.tap(find.widgetWithText(FilledButton, 'Clone'));
    await tester.pumpAndSettle();
    expect(find.text('Use a path inside tank, like tank/copy'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('cloneTarget')), 'tank/copy');
    await tester.tap(find.widgetWithText(FilledButton, 'Clone'));
    await settle(tester);
    expect(server.datasets.map((d) => d['id']), contains('tank/copy'));
    await disconnect(tester);
  });

  testWidgets('clone is not offered when the server cannot', (tester) async {
    await connect(tester);
    server.snapshotClone = false;
    final dataset = (await tester.runAsync(
      () => session.storage.datasets('tank'),
    ))!.firstWhere((d) => d.id == 'tank/media');
    await tester.pumpWidget(
      wrap(SnapshotsScreen(session: session, dataset: dataset)),
    );
    await settle(tester);

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Roll back'), findsOneWidget);
    expect(find.text('Clone'), findsNothing);
    await disconnect(tester);
  });
}
