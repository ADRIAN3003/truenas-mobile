import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/app.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/notifications/alert_taps.dart';
import 'package:truenas_mobile/core/settings/app_settings.dart';
import 'package:truenas_mobile/core/settings/settings_provider.dart';
import 'package:truenas_mobile/features/instances/open_default_server.dart';
import 'package:truenas_mobile/features/server/server_screen.dart';

import '../../support/memory_store.dart';

ServerInstance _server(String id, String name) => ServerInstance(
  id: id,
  name: name,
  // Nothing listens here, so the server screen stays on its error page.
  url: 'http://127.0.0.1:1',
  authMethod: AuthMethod.apiKey,
  username: 'truenas_admin',
  secret: 'key',
);

void main() {
  late ProviderContainer appContainer;

  Future<void> start(
    WidgetTester tester,
    List<ServerInstance> servers, {
    AppSettings settings = const AppSettings(),
    bool autoOpen = true,
    String? launchAlertServer,
  }) async {
    final store = MemoryStore();
    await InstanceRepository(store).save(servers);
    final container = ProviderContainer(
      overrides: [
        instanceRepositoryProvider.overrideWithValue(InstanceRepository(store)),
        initialSettingsProvider.overrideWithValue(settings),
        openDefaultServerProvider.overrideWithValue(autoOpen),
        launchAlertServerProvider.overrideWithValue(launchAlertServer),
      ],
    );
    addTearDown(container.dispose);
    appContainer = container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TrueNasMobileApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a single server opens by itself, and back shows the list', (
    tester,
  ) async {
    await start(tester, [_server('a', 'Home')]);
    expect(find.byType(ServerScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ServerScreen), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('with several servers it opens the chosen one', (tester) async {
    await start(tester, [
      _server('a', 'Home'),
      _server('b', 'Office'),
    ], settings: const AppSettings(defaultServerId: 'b'));
    expect(find.byType(ServerScreen), findsOneWidget);
    expect(
      tester.widget<ServerScreen>(find.byType(ServerScreen)).instanceId,
      'b',
    );
  });

  testWidgets('with several servers and no choice it stays on the list', (
    tester,
  ) async {
    await start(tester, [_server('a', 'Home'), _server('b', 'Office')]);
    expect(find.byType(ServerScreen), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Office'), findsOneWidget);
  });

  testWidgets('choosing none keeps even a single server on the list', (
    tester,
  ) async {
    await start(tester, [
      _server('a', 'Home'),
    ], settings: const AppSettings(defaultServerId: ''));
    expect(find.byType(ServerScreen), findsNothing);
  });

  testWidgets('does nothing unless the app turns it on', (tester) async {
    await start(tester, [_server('a', 'Home')], autoOpen: false);
    expect(find.byType(ServerScreen), findsNothing);
  });

  testWidgets('the default server is marked on its card', (tester) async {
    await start(
      tester,
      [_server('a', 'Home'), _server('b', 'Office')],
      settings: const AppSettings(defaultServerId: 'b'),
      autoOpen: false,
    );
    expect(find.text('Default'), findsOneWidget);
  });

  testWidgets('a tapped alert notification opens its server, not the default', (
    tester,
  ) async {
    await start(
      tester,
      [_server('a', 'Home'), _server('b', 'Office')],
      settings: const AppSettings(defaultServerId: 'a'),
      launchAlertServer: 'b',
    );
    final screen = tester.widget<ServerScreen>(find.byType(ServerScreen));
    expect(screen.instanceId, 'b');
    expect(screen.openAlertsOnStart, isTrue);
    expect(find.byType(ServerScreen), findsOneWidget);
    expect(appContainer.read(pendingAlertServerProvider), isNull);
  });

  testWidgets('a notification tapped while the app runs opens its server', (
    tester,
  ) async {
    await start(tester, [_server('a', 'Home'), _server('b', 'Office')]);
    expect(find.byType(ServerScreen), findsNothing);
    appContainer.read(pendingAlertServerProvider.notifier).open('b');
    await tester.pumpAndSettle();
    final screen = tester.widget<ServerScreen>(find.byType(ServerScreen));
    expect(screen.instanceId, 'b');
    expect(screen.openAlertsOnStart, isTrue);
  });

  testWidgets('a tapped notification of a removed server does nothing', (
    tester,
  ) async {
    await start(tester, [
      _server('a', 'Home'),
      _server('b', 'Office'),
    ], launchAlertServer: 'gone');
    expect(find.byType(ServerScreen), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });
}
