import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';
import 'package:truenas_mobile/features/workloads/apps_tab.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_truenas_server.dart';

void main() {
  late FakeTrueNasServer server;
  late TrueNasSession session;

  Widget wrap(Widget child) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
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

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    await tester.pumpWidget(wrap(AppsTab(session: session)));
    await settle(tester);
  }

  Future<void> stop(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await session.close();
      await server.close();
    });
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('creates a machine with a new disk and a network adapter', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.byTooltip('New virtual machine'));
    await settle(tester);

    await tester.enterText(field('Name'), 'ubuntu');
    await tester.enterText(field('Memory (MiB)'), '4096');
    await tester.enterText(field('Size (GiB)'), '40');
    await tester.enterText(
      field('Install image (path to an ISO)'),
      '/iso/u.iso',
    );
    await tester.tap(find.text('Save'));
    await settle(tester);

    final create = server.calls.firstWhere((c) => c.$1 == 'vm.create');
    final sent = create.$2.single as Map<String, dynamic>;
    expect(sent['name'], 'ubuntu');
    expect(sent['memory'], 4096);
    final devices = (sent['devices'] as List).cast<Map<String, dynamic>>();
    expect(devices.map((d) => (d['attributes'] as Map)['dtype']), [
      'DISK',
      'CDROM',
      'NIC',
    ]);
    expect(devices.first['attributes'], {
      'dtype': 'DISK',
      'type': 'VIRTIO',
      'create_zvol': true,
      'zvol_name': 'tank/ubuntu-disk0',
      'zvol_volsize': 40 * 1024 * 1024 * 1024,
    });
    expect(devices.last['attributes'], {
      'dtype': 'NIC',
      'type': 'VIRTIO',
      'nic_attach': 'enp1s0',
    });
    // Back on the list, which now has the machine.
    expect(find.text('Created ubuntu'), findsOneWidget);
    expect(find.text('ubuntu'), findsOneWidget);
    await stop(tester);
  });

  testWidgets('a name is required', (tester) async {
    await start(tester);
    await tester.tap(find.byTooltip('New virtual machine'));
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Required'), findsWidgets);
    expect(server.calls.map((c) => c.$1), isNot(contains('vm.create')));
    await stop(tester);
  });

  testWidgets('shows the devices and changes only the edited settings', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.text('win11'));
    await settle(tester);

    expect(find.text('Disk (zvol)'), findsOneWidget);
    expect(find.text('/dev/zvol/tank/win11'), findsOneWidget);
    expect(find.text('Network adapter'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit'));
    await settle(tester);
    await tester.enterText(field('Memory (MiB)'), '16384');
    await tester.tap(find.text('Save'));
    await settle(tester);

    final update = server.calls.firstWhere((c) => c.$1 == 'vm.update');
    expect(update.$2, [
      1,
      {'memory': 16384},
    ]);
    // The machine's screen shows the new size.
    expect(find.text('16.0 GiB'), findsOneWidget);
    await stop(tester);
  });

  testWidgets('adds a CD-ROM, changes a network adapter, removes a disk', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.text('win11'));
    await settle(tester);

    // Add.
    await tester.tap(find.byTooltip('Add device'));
    await settle(tester);
    await tester.tap(find.text('CD-ROM (ISO)').last);
    await settle(tester);
    await tester.enterText(field('Path'), '/mnt/tank/win11.iso');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(
      server.vmDevices
          .map((d) => d['attributes'] as Map)
          .where((a) => a['dtype'] == 'CDROM')
          .single,
      {'dtype': 'CDROM', 'path': '/mnt/tank/win11.iso'},
    );

    // Change: keeps the attributes the form doesn't show.
    await tester.tap(find.text('enp1s0 · 00:a0:98:11:22:33'));
    await settle(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String?>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('br0').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await settle(tester);
    final nic = server.vmDevices.firstWhere((d) => d['id'] == 11);
    expect((nic['attributes'] as Map)['nic_attach'], 'br0');
    expect((nic['attributes'] as Map)['mac'], '00:a0:98:11:22:33');
    expect((nic['attributes'] as Map)['dtype'], 'NIC');

    // Remove, also destroying the zvol.
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await settle(tester);
    expect(server.vmDevices.any((d) => d['id'] == 10), isFalse);
    expect(
      server.calls.firstWhere((c) => c.$1 == 'vm.device.delete').$2[1],
      containsPair('zvol', true),
    );
    await stop(tester);
  });

  testWidgets('shows a spinner while the machine loads, then named devices', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.text('win11'));
    // The first frame, before the server has answered.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await settle(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // 25.04 rows: the kind is inside the attributes, and the form is drawn
    // for it instead of a JSON box.
    await tester.tap(find.text('Disk (zvol)'));
    await settle(tester);
    expect(find.text('Edit Disk (zvol)'), findsOneWidget);
    expect(find.text('Attributes (JSON)'), findsNothing);
    expect(find.text('Bus'), findsOneWidget);
    await stop(tester);
  });

  testWidgets('deleting a machine asks for its name first', (tester) async {
    await start(tester);
    await tester.tap(find.text('win11'));
    await settle(tester);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete win11?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'win11');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);

    expect(server.calls.firstWhere((c) => c.$1 == 'vm.delete').$2, [
      1,
      {'zvols': false, 'force': false},
    ]);
    expect(server.vms, isEmpty);
    await stop(tester);
  });

  testWidgets('a server without the VM methods offers no editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      server = await FakeTrueNasServer.start();
      server.vmEditor = false;
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
    await tester.pumpWidget(wrap(AppsTab(session: session)));
    await settle(tester);
    expect(find.byTooltip('New virtual machine'), findsNothing);
    await stop(tester);
  });
}
