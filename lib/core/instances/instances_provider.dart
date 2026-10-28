import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'instance_repository.dart';
import 'server_instance.dart';

final instanceRepositoryProvider = Provider<InstanceRepository>(
  (ref) => const InstanceRepository(SecureKeyValueStore()),
);

final instancesProvider =
    AsyncNotifierProvider<InstancesNotifier, List<ServerInstance>>(
      InstancesNotifier.new,
    );

class InstancesNotifier extends AsyncNotifier<List<ServerInstance>> {
  /// Changes run one after the other, each on the list the one before left,
  /// so two saves close together (a new server and a refreshed certificate
  /// pin) cannot overwrite each other.
  Future<void> _queue = Future.value();

  @override
  Future<List<ServerInstance>> build() =>
      ref.read(instanceRepositoryProvider).load();

  /// Adds [instance], or replaces the saved one with the same id.
  Future<void> upsert(ServerInstance instance) => _change((current) {
    final index = current.indexWhere((e) => e.id == instance.id);
    final next = [...current];
    if (index == -1) {
      next.add(instance);
    } else {
      next[index] = instance;
    }
    return next;
  });

  Future<void> remove(String id) =>
      _change((current) => current.where((e) => e.id != id).toList());

  /// Reads the saved servers again after a failed read.
  void retry() => ref.invalidateSelf();

  /// Forgets every saved server, for when they cannot be read at all. If
  /// even writing the empty list fails (the key behind the secure storage is
  /// gone or unusable), the storage is reset, which also drops the other
  /// things kept in it, and the list is written again.
  Future<void> clear() async {
    final result = _queue.then((_) async {
      try {
        await _persist(const []);
      } catch (_) {
        await ref.read(instanceRepositoryProvider).reset();
        await _persist(const []);
      }
    });
    _queue = result.catchError((_) {});
    await result;
  }

  Future<void> _change(
    List<ServerInstance> Function(List<ServerInstance> current) edit,
  ) {
    final result = _queue.then((_) async {
      await _persist(edit(await _current()));
    });
    _queue = result.catchError((_) {});
    return result;
  }

  /// The saved servers. When the first read failed it is tried again here
  /// and, if that fails too, the error is thrown: a list that could not be
  /// read is never replaced by one that has only the new server.
  Future<List<ServerInstance>> _current() async {
    try {
      return await future;
    } catch (_) {
      final loaded = await ref.read(instanceRepositoryProvider).load();
      state = AsyncData(loaded);
      return loaded;
    }
  }

  Future<void> _persist(List<ServerInstance> next) async {
    await ref.read(instanceRepositoryProvider).save(next);
    state = AsyncData(next);
  }
}

/// A random id for a new server.
String newInstanceId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
