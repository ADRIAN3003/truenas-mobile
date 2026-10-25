import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/wol/wake_on_lan.dart';
import 'package:truenas_mobile/features/instances/server_form_screen.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_truenas_server.dart';
import '../../support/memory_store.dart';

const _saved = ServerInstance(
  id: 'a',
  name: 'Home NAS',
  url: 'https://nas.local',
  authMethod: AuthMethod.password,
  username: 'truenas_admin',
  secret: 'hunter2',
);

void main() {
  late MemoryStore store;

  Future<void> openForm(WidgetTester tester, {ServerInstance? edit}) async {
    // Tall enough for the whole form, since a list only builds what shows.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Start from nothing, so a form opened again does not sit on a navigator
    // whose only route has just been popped.
    await tester.pumpWidget(const SizedBox.shrink());
    store = MemoryStore();
    if (edit != null) await InstanceRepository(store).save([edit]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          instanceRepositoryProvider.overrideWithValue(
            InstanceRepository(store),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ServerFormScreen(instance: edit),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TextField secretField(WidgetTester tester) => tester.widget<TextField>(
    find.descendant(
      of: find.byKey(const Key('secret')),
      matching: find.byType(TextField),
    ),
  );

  Future<ServerInstance> savedServer() async =>
      (await InstanceRepository(store).load()).single;

  testWidgets('editing never shows the saved password', (tester) async {
    await openForm(tester, edit: _saved);
    expect(secretField(tester).controller!.text, isEmpty);
    expect(find.text('hunter2'), findsNothing);
    expect(
      find.textContaining('Leave empty to keep the saved password'),
      findsOneWidget,
    );
  });

  testWidgets('an empty password field keeps the saved one', (tester) async {
    await openForm(tester, edit: _saved);
    await tester.enterText(find.byType(TextFormField).first, 'Office NAS');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final server = await savedServer();
    expect(server.name, 'Office NAS');
    expect(server.secret, 'hunter2');
  });

  testWidgets('typing a password replaces the saved one', (tester) async {
    await openForm(tester, edit: _saved);
    await tester.enterText(find.byKey(const Key('secret')), 'correct horse');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await savedServer()).secret, 'correct horse');
  });

  testWidgets('another sign-in method needs its own secret', (tester) async {
    await openForm(tester, edit: _saved);
    await tester.tap(find.text('API key'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Leave empty'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);
    expect((await savedServer()).secret, 'hunter2');
  });

  testWidgets('a new server still needs a password', (tester) async {
    await openForm(tester);
    await tester.enterText(find.byKey(const Key('address')), 'nas.local');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);
    expect(await InstanceRepository(store).load(), isEmpty);
  });

  group('Wake-on-LAN', () {
    Future<void> fill(WidgetTester tester, String key, String text) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.enterText(find.byKey(Key(key)), text);
    }

    Future<void> save(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('a server without a MAC address is saved without it', (
      tester,
    ) async {
      await openForm(tester, edit: _saved);
      await save(tester);
      expect((await savedServer()).wol, isNull);
    });

    testWidgets('the settings are saved with the defaults filled in', (
      tester,
    ) async {
      await openForm(tester, edit: _saved);
      await fill(tester, 'wolMac', 'aa-bb-cc-dd-ee-ff');
      await save(tester);
      expect(
        (await savedServer()).wol,
        const WakeOnLanSettings(mac: 'AA:BB:CC:DD:EE:FF'),
      );
    });

    testWidgets('a broadcast address and port are kept and shown again', (
      tester,
    ) async {
      await openForm(tester, edit: _saved);
      await fill(tester, 'wolMac', 'AA:BB:CC:DD:EE:FF');
      await fill(tester, 'wolBroadcast', '192.168.1.255');
      await fill(tester, 'wolPort', '7');
      await save(tester);
      final server = await savedServer();
      expect(server.wol?.broadcast, '192.168.1.255');
      expect(server.wol?.port, 7);

      await openForm(tester, edit: server);
      await tester.ensureVisible(find.byKey(const Key('wolMac')));
      expect(find.text('AA:BB:CC:DD:EE:FF'), findsWidgets);
      expect(find.text('192.168.1.255'), findsWidgets);
      expect(find.text('7'), findsWidgets);
    });

    testWidgets('a MAC address or port that cannot be read blocks saving', (
      tester,
    ) async {
      await openForm(tester, edit: _saved);
      await fill(tester, 'wolMac', 'not a mac');
      await fill(tester, 'wolPort', '70000');
      await save(tester);
      expect(find.text('Enter a MAC address like AA:BB:CC:DD:EE:FF'), findsOne);
      expect(find.text('Enter a port from 1 to 65535'), findsOneWidget);
      expect((await savedServer()).wol, isNull);
    });

    testWidgets('the MAC address can be read from the server', (tester) async {
      HttpOverrides.global = null;
      late FakeTrueNasServer server;
      await tester.runAsync(() async {
        server = await FakeTrueNasServer.start();
      });
      addTearDown(() => server.close());
      await openForm(
        tester,
        edit: ServerInstance(
          id: 'a',
          name: 'Home NAS',
          url: 'http://127.0.0.1:${server.port}',
          authMethod: AuthMethod.password,
          username: 'truenas_admin',
          secret: 'secret',
        ),
      );
      await tester.ensureVisible(
        find.text('Get the MAC address from the server'),
      );
      await tester.tap(find.text('Get the MAC address from the server'));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      // Two cards report one: pick the second.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('enp2s0 · aa:bb:cc:dd:ee:02'));
      await tester.pumpAndSettle();
      expect(find.text('AA:BB:CC:DD:EE:02'), findsOneWidget);
    });
  });
}
