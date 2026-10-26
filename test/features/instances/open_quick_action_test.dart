import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/app.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/quick_actions/quick_actions.dart';
import 'package:truenas_mobile/features/instances/open_default_server.dart';
import 'package:truenas_mobile/features/server/server_screen.dart';

import '../../support/memory_store.dart';
import '../../support/quick_action_fakes.dart';

ServerInstance _server(String id, String name) => ServerInstance(
  id: id,
  name: name,
  // Nothing listens here, so the server screen stays on its error page.
  url: 'http://127.0.0.1:1',
  authMethod: AuthMethod.apiKey,
  username: 'truenas_admin',
  secret: 'key',
);

const _restart = QuickAction(
  serverId: 'b',
  kind: QuickActionKind.appRestart,
  target: 'plex',
);

void main() {
  Future<void> start(
    WidgetTester tester,
    FakeQuickActions quickActions, {
    bool autoOpen = false,
  }) async {
    final store = MemoryStore();
    await InstanceRepository(store)
        .save([_server('a', 'Home'), _server('b', 'Office')]);
    final container = ProviderContainer(
      overrides: [
        instanceRepositoryProvider.overrideWithValue(InstanceRepository(store)),
        openDefaultServerProvider.overrideWithValue(autoOpen),
        quickActionsProvider.overrideWithValue(quickActions),
        launchQuickActionProvider.overrideWithValue(quickActions.launch),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TrueNasMobileApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  ServerScreen opened(WidgetTester tester) =>
      tester.widget<ServerScreen>(find.byType(ServerScreen));

  testWidgets('a shortcut that started the app opens its server', (
    tester,
  ) async {
    await start(tester, FakeQuickActions(launch: _restart));
    expect(opened(tester).instanceId, 'b');
    expect(opened(tester).quickAction, _restart);
  });

  testWidgets('it takes the place of the default server', (tester) async {
    await start(tester, FakeQuickActions(launch: _restart), autoOpen: true);
    expect(find.byType(ServerScreen), findsOneWidget);
    expect(opened(tester).instanceId, 'b');
  });

  testWidgets('a shortcut tapped while the app is open opens its server', (
    tester,
  ) async {
    final quickActions = FakeQuickActions();
    await start(tester, quickActions);
    expect(find.byType(ServerScreen), findsNothing);
    quickActions.tap(_restart);
    await tester.pumpAndSettle();
    expect(opened(tester).quickAction, _restart);
  });

  testWidgets('a shortcut of a removed server does nothing', (tester) async {
    await start(
      tester,
      FakeQuickActions(
        launch: const QuickAction(
          serverId: 'gone',
          kind: QuickActionKind.appStart,
          target: 'plex',
        ),
      ),
    );
    expect(find.byType(ServerScreen), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });
}
