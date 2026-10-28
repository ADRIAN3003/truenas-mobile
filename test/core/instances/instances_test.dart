import 'package:flutter/services.dart';
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

  group('when storage fails', () {
    const office = ServerInstance(
      id: 'b',
      name: 'Office',
      url: 'https://office.local',
      authMethod: AuthMethod.apiKey,
      username: 'truenas_admin',
      secret: '2-key',
    );

    ProviderContainer open(FlakyStore store) {
      final container = ProviderContainer(
        overrides: [
          instanceRepositoryProvider.overrideWithValue(
            InstanceRepository(store, retryDelay: Duration.zero),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('a read that fails once is tried again', () async {
      final store = FlakyStore();
      await InstanceRepository(store).save([_home]);
      store.failReads = 2;
      final loaded = await InstanceRepository(
        store,
        retryDelay: Duration.zero,
      ).load();
      expect(loaded.single.id, 'a');
    });

    test('a read that keeps failing throws, not "no servers"', () async {
      final store = FlakyStore()..failReads = 99;
      await expectLater(
        InstanceRepository(store, retryDelay: Duration.zero).load(),
        throwsStateError,
      );
    });

    test('saving never replaces servers that could not be read', () async {
      final store = FlakyStore();
      await InstanceRepository(store).save([_home]);
      store.failReads = 99;
      final container = open(store);
      final notifier = container.read(instancesProvider.notifier);
      await expectLater(
        container.read(instancesProvider.future),
        throwsStateError,
      );

      await expectLater(notifier.upsert(office), throwsStateError);
      final saved = await InstanceRepository(
        MemoryStore()..values.addAll(store.values),
      ).load();
      expect(saved.single.id, 'a');

      // Storage recovers: the server that was there is kept next to the new.
      store.failReads = 0;
      await notifier.upsert(office);
      expect(container.read(instancesProvider).value!.map((e) => e.id), [
        'a',
        'b',
      ]);
      expect((await InstanceRepository(store).load()).map((e) => e.id), [
        'a',
        'b',
      ]);
    });

    test('retry reads the servers again', () async {
      final store = FlakyStore();
      await InstanceRepository(store).save([_home]);
      store.failReads = 99;
      final container = open(store);
      final sub = container.listen(instancesProvider, (_, _) {});
      addTearDown(sub.close);
      await expectLater(
        container.read(instancesProvider.future),
        throwsStateError,
      );

      store.failReads = 0;
      container.read(instancesProvider.notifier).retry();
      expect((await container.read(instancesProvider.future)).single.id, 'a');
    });

    test('clear starts over when the servers cannot be read', () async {
      final store = FlakyStore();
      await InstanceRepository(store).save([_home]);
      store.failReads = 99;
      final container = open(store);
      await expectLater(
        container.read(instancesProvider.future),
        throwsStateError,
      );

      await container.read(instancesProvider.notifier).clear();
      expect(container.read(instancesProvider).value, isEmpty);
    });

    test('clear resets the storage when even writing to it fails', () async {
      final store = FlakyStore();
      await InstanceRepository(store).save([_home]);
      store.failReads = 99;
      store.failWrites = 1;
      final container = open(store);
      await expectLater(
        container.read(instancesProvider.future),
        throwsStateError,
      );

      await container.read(instancesProvider.notifier).clear();
      expect(store.resets, 1);
      expect(container.read(instancesProvider).value, isEmpty);
    });

    test('clear does not reset the storage when a write works', () async {
      final store = FlakyStore();
      await InstanceRepository(store).save([_home]);
      final container = open(store);
      await container.read(instancesProvider.future);

      await container.read(instancesProvider.notifier).clear();
      expect(store.resets, 0);
    });

    test('a storage error is summed up in one line', () {
      expect(
        storageErrorSummary(
          PlatformException(
            code: 'Exception encountered',
            message: 'Migration failed after algorithm change\nmore',
            details: 'java.lang.Exception: ...',
          ),
        ),
        'Migration failed after algorithm change',
      );
      expect(storageErrorSummary(StateError('x' * 400)).length, 243);
    });

    test('a failed write leaves the list as it was', () async {
      final store = FlakyStore();
      final container = open(store);
      final notifier = container.read(instancesProvider.notifier);
      await container.read(instancesProvider.future);
      await notifier.upsert(_home);

      store.failWrites = 1;
      await expectLater(notifier.upsert(office), throwsStateError);
      expect(container.read(instancesProvider).value!.map((e) => e.id), ['a']);

      // The queue is not stuck by the failure.
      await notifier.upsert(office);
      expect(container.read(instancesProvider).value!.map((e) => e.id), [
        'a',
        'b',
      ]);
    });

    test('saves made at the same moment are both kept', () async {
      final store = FlakyStore();
      final container = open(store);
      final notifier = container.read(instancesProvider.notifier);
      await container.read(instancesProvider.future);

      await Future.wait([notifier.upsert(_home), notifier.upsert(office)]);
      expect(
        (await InstanceRepository(store).load()).map((e) => e.id),
        unorderedEquals(['a', 'b']),
      );
    });
  });

  test(
    'the secure store does not erase everything when a read fails',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      Object? options;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            options = (call.arguments as Map)['options'];
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      await const SecureKeyValueStore().read('servers.v1');
      expect((options! as Map)['resetOnError'], 'false');
    },
  );

  test('copyWith can clear the pinned certificate', () {
    expect(
      _home.copyWith(pinnedFingerprint: () => null).pinnedFingerprint,
      isNull,
    );
  });
}
