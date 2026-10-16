import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/app.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';

import 'support/memory_store.dart';

Widget _app(MemoryStore store) => ProviderScope(
  overrides: [
    instanceRepositoryProvider.overrideWithValue(InstanceRepository(store)),
  ],
  child: const TrueNasMobileApp(),
);

void main() {
  testWidgets('shows the empty server list', (tester) async {
    await tester.pumpWidget(_app(MemoryStore()));
    await tester.pumpAndSettle();
    expect(find.text('No servers yet'), findsOneWidget);
    expect(find.text('Add server'), findsOneWidget);
  });

  testWidgets('follows a Hungarian device language', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('hu', 'HU')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(_app(MemoryStore()));
    await tester.pumpAndSettle();
    expect(find.text('Még nincs szerver'), findsOneWidget);
    expect(find.text('Szerver hozzáadása'), findsOneWidget);
  });

  testWidgets('lists saved servers', (tester) async {
    final store = MemoryStore();
    await InstanceRepository(store).save([
      const ServerInstance(
        id: 'a',
        name: 'Home NAS',
        url: 'https://nas.local',
        authMethod: AuthMethod.apiKey,
        username: 'truenas_admin',
        secret: 'key',
        lastApiVersion: 'v25.10.5',
      ),
    ]);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    expect(find.text('Home NAS'), findsOneWidget);
    // The address without scheme, then what the card knows about the server.
    expect(find.text('nas.local'), findsOneWidget);
    expect(find.text('1 server'), findsOneWidget);
    expect(find.text('HTTPS'), findsOneWidget);
    expect(find.text('API v25.10.5'), findsOneWidget);
    expect(find.text('API key'), findsOneWidget);
  });

  testWidgets('a long name and address fit a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    await InstanceRepository(store).save([
      const ServerInstance(
        id: 'a',
        name: 'Backup server in the garage, second floor',
        url: 'https://truenas.very-long-hostname.home.example.com:8443',
        authMethod: AuthMethod.password,
        username: 'truenas_admin',
        secret: 'pw',
        lastApiVersion: 'v25.10.5',
      ),
    ]);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.text('truenas.very-long-hostname.home.example.com:8443'),
      findsOneWidget,
    );
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('adds a server from the form', (tester) async {
    final store = MemoryStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('address')),
      'http://nas.local',
    );
    await tester.enterText(find.byKey(const Key('secret')), '1-key');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('API keys need HTTPS'),
      findsOneWidget,
      reason: 'API keys must not be sent over plain HTTP',
    );

    await tester.enterText(find.byKey(const Key('address')), 'nas.local');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('1 server'), findsOneWidget);
    final saved = await InstanceRepository(store).load();
    expect(saved.single.url, 'https://nas.local');
    expect(saved.single.username, 'truenas_admin');
  });
}
