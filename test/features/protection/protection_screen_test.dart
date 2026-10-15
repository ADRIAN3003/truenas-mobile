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

    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Periodic snapshots').last);
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

  Map<String, dynamic> lastCall(String method, [int index = 0]) =>
      server.calls.lastWhere((c) => c.$1 == method).$2[index]
          as Map<String, dynamic>;

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(of: find.byType(Form), matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('adds a replication task bound to a snapshot task', (
    tester,
  ) async {
    await connect(tester);
    await tester.pumpWidget(wrap(ProtectionScreen(session: session)));
    await settle(tester);

    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replication').last);
    await settle(tester);
    expect(find.text('New replication task'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsWidgets);
    expect(
      server.calls.map((c) => c.$1),
      isNot(contains('replication.create')),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'to-backup',
    );
    await tester.tap(find.byTooltip('Choose a dataset').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('tank/media').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Destination dataset'),
      'tank/backup',
    );
    await tapVisible(tester, find.widgetWithText(FilterChip, 'tank/media'));
    await tester.ensureVisible(find.text('Right after the snapshot task'));
    expect(find.text('Snapshot name pattern'), findsNothing);

    await tester.tap(find.text('Save'));
    await settle(tester);
    final created = lastCall('replication.create');
    expect(created['name'], 'to-backup');
    expect(created['direction'], 'PUSH');
    expect(created['transport'], 'LOCAL');
    expect(created['ssh_credentials'], isNull);
    expect(created['source_datasets'], ['tank/media']);
    expect(created['target_dataset'], 'tank/backup');
    expect(created['periodic_snapshot_tasks'], [1]);
    expect(created['also_include_naming_schema'], isEmpty);
    expect(created['auto'], isTrue);
    expect(created['schedule'], isNull);
    expect(created['retention_policy'], 'SOURCE');
    expect(find.text('New replication task'), findsNothing);
    expect(find.text('to-backup'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('edits a replication task to go over SSH', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(ProtectionScreen(session: session)));
    await settle(tester);

    await tester.tap(find.text('offsite'));
    await settle(tester);
    expect(find.text('Edit replication task'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'offsite'), findsOneWidget);

    await tester.tap(find.text('Another pool on this server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Another server over SSH').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('backup-box').last);
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Same as the source'));
    await tester.tap(find.text('For a set time').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await settle(tester);
    final call = server.calls.lastWhere((c) => c.$1 == 'replication.update');
    expect(call.$2.first, 1);
    final update = call.$2[1] as Map<String, dynamic>;
    expect(update['transport'], 'SSH');
    expect(update['ssh_credentials'], 3);
    expect(update['also_include_naming_schema'], ['auto-%Y-%m-%d_%H-%M']);
    expect(update['schedule'], containsPair('hour', '0'));
    expect(update['retention_policy'], 'CUSTOM');
    expect(update['lifetime_value'], 2);
    expect(update['lifetime_unit'], 'WEEK');
    await disconnect(tester);
  });

  testWidgets('adds a cloud sync task', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(ProtectionScreen(session: session)));
    await settle(tester);

    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cloud sync').last);
    await settle(tester);
    expect(find.text('New cloud sync task'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backblaze (B2)').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Bucket'),
      'photos',
    );
    await tester.tap(find.byTooltip('Choose a dataset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('tank/media').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await settle(tester);
    final created = lastCall('cloudsync.create');
    expect(created['credentials'], 1);
    expect(created['path'], '/mnt/tank/media');
    expect(created['direction'], 'PUSH');
    expect(created['transfer_mode'], 'COPY');
    expect(created['attributes'], {'bucket': 'photos', 'folder': ''});
    expect(created['schedule'], containsPair('hour', '0'));
    await disconnect(tester);
  });

  testWidgets('adds a TrueCloud backup task', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(ProtectionScreen(session: session)));
    await settle(tester);

    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TrueCloud backup').last);
    await settle(tester);
    expect(find.text('New TrueCloud backup task'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backblaze (B2)').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Bucket'),
      'backups',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Local folder'),
      '/mnt/tank/media',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Repository password'),
      'hunter2',
    );
    await tester.tap(find.text('Save'));
    await settle(tester);
    final created = lastCall('cloud_backup.create');
    expect(created['credentials'], 1);
    expect(created['path'], '/mnt/tank/media');
    expect(created['password'], 'hunter2');
    expect(created['keep_last'], 14);
    expect(created['attributes'], {'bucket': 'backups', 'folder': ''});
    await disconnect(tester);
  });

  testWidgets('edits an rsync task to go over SSH', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(ProtectionScreen(session: session)));
    await settle(tester);

    await tester.scrollUntilVisible(find.text('Mirror to backup box'), 100);
    // Clear the floating Add task button.
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mirror to backup box'));
    await settle(tester);
    expect(find.text('Edit rsync task'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'media'), findsOneWidget);

    await tester.tap(find.text('Rsync daemon module'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSH').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter a host instead'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('backup-box').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.widgetWithText(TextFormField, 'Remote path'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Remote path'),
      '/srv/media',
    );

    await tester.tap(find.text('Save'));
    await settle(tester);
    final call = server.calls.lastWhere((c) => c.$1 == 'rsynctask.update');
    expect(call.$2.first, 1);
    final update = call.$2[1] as Map<String, dynamic>;
    expect(update['mode'], 'SSH');
    expect(update['ssh_credentials'], 3);
    expect(update['remotehost'], isNull);
    expect(update['remotemodule'], isNull);
    expect(update['remotepath'], '/srv/media');
    expect(update['schedule'], containsPair('dow', '0'));
    await disconnect(tester);
  });
}
