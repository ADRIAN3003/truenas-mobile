import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';
import 'package:truenas_mobile/features/sharing/nfs_shares_screen.dart';
import 'package:truenas_mobile/features/sharing/services_screen.dart';
import 'package:truenas_mobile/features/sharing/shares_tab.dart';
import 'package:truenas_mobile/features/sharing/smb_shares_screen.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';
import 'package:truenas_mobile/shared/ui.dart';

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
    for (var i = 0; i < 8; i++) {
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

  testWidgets('shares tab summarises every protocol', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(Scaffold(body: SharesTab(session: session))));
    await settle(tester);

    expect(find.text('SMB shares'), findsOneWidget);
    expect(find.text('NFS shares'), findsOneWidget);
    expect(find.text('1 share'), findsNWidgets(2));
    expect(find.text('Targets: 1 · Extents: 1'), findsOneWidget);
    expect(find.text('Subsystems: 1'), findsOneWidget);
    expect(find.text('Services'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('services can be started and set to start on boot', (
    tester,
  ) async {
    await connect(tester);
    await tester.pumpWidget(wrap(ServicesScreen(session: session)));
    await settle(tester);

    expect(find.text('NFS'), findsOneWidget);
    expect(find.text('Stopped'), findsOneWidget);
    await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start').last);
    await settle(tester);
    expect(server.services[1]['state'], 'RUNNING');
    expect(find.text('Stopped'), findsNothing);

    await tester.tap(find.byType(Switch).first);
    await settle(tester);
    expect(server.services[1]['enable'], isTrue);
    await disconnect(tester);
  });

  testWidgets('SMB shares can be added and switched off', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(SmbSharesScreen(session: session)));
    await settle(tester);

    expect(find.text('media'), findsOneWidget);
    expect(find.text('/mnt/tank/media'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(server.smbShares.single['enabled'], isFalse);

    await tester.tap(find.text('Add share'));
    await settle(tester);
    // The name defaults to the folder's last component.
    expect(find.widgetWithText(TextFormField, 'tank'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('shareName')), 'everything');
    await tester.tap(find.text('Create'));
    await settle(tester);
    expect(server.smbShares.last['name'], 'everything');
    expect(server.smbShares.last['path'], '/mnt/tank');
    await disconnect(tester);
  });

  testWidgets('NFS share edit can make it writable or delete it', (
    tester,
  ) async {
    await connect(tester);
    await tester.pumpWidget(wrap(NfsSharesScreen(session: session)));
    await settle(tester);

    expect(find.text('Allowed: 192.168.1.0/24'), findsOneWidget);
    // The NFS service is stopped in the fake, so a banner offers to start it.
    expect(find.textContaining('NFS service is stopped'), findsOneWidget);

    await tester.tap(find.text('/mnt/tank/media'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppSwitchTile, 'Read only'));
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(server.nfsShares.single['ro'], isFalse);

    await tester.tap(find.text('/mnt/tank/media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete share'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
    expect(server.nfsShares, isEmpty);
    expect(find.text('No shares yet'), findsOneWidget);
    await disconnect(tester);
  });
}
