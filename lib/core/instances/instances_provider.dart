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
  @override
  Future<List<ServerInstance>> build() =>
      ref.read(instanceRepositoryProvider).load();

  /// Adds [instance], or replaces the saved one with the same id.
  Future<void> upsert(ServerInstance instance) async {
    final current = await future;
    final index = current.indexWhere((e) => e.id == instance.id);
    final next = [...current];
    if (index == -1) {
      next.add(instance);
    } else {
      next[index] = instance;
    }
    await _persist(next);
  }

  Future<void> remove(String id) async {
    final current = await future;
    await _persist(current.where((e) => e.id != id).toList());
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
