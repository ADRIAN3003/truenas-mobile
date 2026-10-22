import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/app.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/settings/app_settings.dart';
import 'package:truenas_mobile/core/settings/settings_provider.dart';
import 'package:truenas_mobile/core/widgets/home_widgets.dart';
import 'package:truenas_mobile/features/instances/open_default_server.dart';

import '../../support/home_widget_fakes.dart';
import '../../support/memory_store.dart';

ServerInstance _server(String id, String name) => ServerInstance(
  id: id,
  name: name,
  url: 'http://127.0.0.1:1',
  authMethod: AuthMethod.apiKey,
  username: 'truenas_admin',
  secret: 'key',
);

void main() {
  late FakeHomeWidgets widgets;
  late ProviderContainer container;

  Future<void> start(
    WidgetTester tester,
    List<ServerInstance> servers, {
    AppSettings settings = const AppSettings(),
  }) async {
    widgets = FakeHomeWidgets();
    final store = MemoryStore();
    await InstanceRepository(store).save(servers);
    container = ProviderContainer(
      overrides: [
        instanceRepositoryProvider.overrideWithValue(InstanceRepository(store)),
        initialSettingsProvider.overrideWithValue(settings),
        openDefaultServerProvider.overrideWithValue(false),
        homeWidgetsBridgeProvider.overrideWithValue(widgets),
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

  testWidgets('saved servers reach the widgets before any is opened', (
    tester,
  ) async {
    await start(tester, [_server('a', 'Home'), _server('b', 'Office')]);
    expect(widgets.servers.keys, ['a', 'b']);
    expect(widgets.servers['b']!['name'], 'Office');
    expect(widgets.json['labels'], isNotEmpty);
  });

  testWidgets('a server added later is listed too', (tester) async {
    await start(tester, [_server('a', 'Home')]);
    await container
        .read(instancesProvider.notifier)
        .upsert(_server('b', 'Lab'));
    await tester.pumpAndSettle();
    expect(widgets.servers.keys, ['a', 'b']);
  });

  testWidgets('nothing is written with the widgets switched off', (
    tester,
  ) async {
    await start(tester, [
      _server('a', 'Home'),
    ], settings: const AppSettings(homeWidgets: false));
    expect(widgets.document, isNull);
    // But whatever the iOS widgets held to sign in with is taken away.
    expect(widgets.credentialWrites, isNotEmpty);
    expect(widgets.credentialWrites.every((json) => json == null), isTrue);
  });

  testWidgets('the iOS widgets get the sign-in details of saved servers', (
    tester,
  ) async {
    await start(tester, [_server('a', 'Home')]);
    expect(widgets.credentials, contains('"secret":"key"'));
  });
}
