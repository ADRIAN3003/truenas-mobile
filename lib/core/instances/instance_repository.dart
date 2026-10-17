import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'server_instance.dart';

/// Minimal key-value storage, so tests can swap out secure storage.
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecureKeyValueStore implements KeyValueStore {
  /// [KeychainAccessibility.first_unlock] instead of the default "unlocked",
  /// so the background alert check can read the saved servers while the phone
  /// is locked. Items saved earlier are found as before and move to this
  /// level the next time they are written.
  const SecureKeyValueStore([
    this._storage = const FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// Loads and saves the list of servers as one JSON document.
class InstanceRepository {
  const InstanceRepository(this._store);

  /// The storage key of the saved servers.
  static const storageKey = 'servers.v1';

  final KeyValueStore _store;

  Future<List<ServerInstance>> load() async {
    final raw = await _store.read(storageKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => ServerInstance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<ServerInstance> instances) => _store.write(
    storageKey,
    jsonEncode(instances.map((e) => e.toJson()).toList()),
  );
}
