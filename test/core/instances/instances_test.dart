import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';

import '../../support/memory_store.dart';

const _home = ServerInstance(
  id: 'a',
  name: 'Home',
  url: 'https://nas.local',
  authMethod: AuthMethod.apiKey,
  username: 'truenas_admin',
  secret: '1-key',
  pinnedFingerprint: 'AA:BB',
);

void main() {
  test('repository round-trips servers through storage', () async {
    final store = MemoryStore();
    final repository = InstanceRepository(store);
    expect(await repository.load(), isEmpty);

    await repository.save([_home]);
    final loaded = await repository.load();
    expect(loaded.single.toJson(), _home.toJson());
  });

  test('notifier adds, updates and removes servers', () async {
    final store = MemoryStore();
    final container = ProviderContainer(
      overrides: [
        instanceRepositoryProvider.overrideWithValue(InstanceRepository(store)),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(instancesProvider.notifier);

    await container.read(instancesProvider.future);
    await notifier.upsert(_home);
    await notifier.upsert(_home.copyWith(name: 'Office'));
    expect(container.read(instancesProvider).value!.single.name, 'Office');

    await notifier.remove('a');
    expect(container.read(instancesProvider).value, isEmpty);
    expect(await InstanceRepository(store).load(), isEmpty);
  });

  test('copyWith can clear the pinned certificate', () {
    expect(
      _home.copyWith(pinnedFingerprint: () => null).pinnedFingerprint,
      isNull,
    );
  });
}
