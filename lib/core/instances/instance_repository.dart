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
  ///
  /// `resetOnError: false` because the Android default erases everything the
  /// moment one read fails (a Keystore that is not ready yet, the background
  /// check starting up, a restored backup). That is how a saved server
  /// vanished; now a failed read is only an error that can be retried.
  const SecureKeyValueStore([
    this._storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
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
  const InstanceRepository(
    this._store, {
    this.retryDelay = const Duration(milliseconds: 300),
  });

  /// The storage key of the saved servers.
  static const storageKey = 'servers.v1';

  final KeyValueStore _store;

  /// Pause before the second and third read when storage throws.
  final Duration retryDelay;

  /// The saved servers. A storage error is thrown, never turned into an empty
  /// list, so the caller cannot mistake "could not read" for "none saved" and
  /// save over them.
  Future<List<ServerInstance>> load() async {
    final raw = await _read();
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => ServerInstance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Android's Keystore can fail for a moment (right after boot or an
  /// update), so a failed read is tried again before it counts.
  Future<String?> _read() async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await _store.read(storageKey);
      } catch (_) {
        if (attempt == 3) rethrow;
        await Future<void>.delayed(retryDelay);
      }
    }
  }

  Future<void> save(List<ServerInstance> instances) => _store.write(
    storageKey,
    jsonEncode(instances.map((e) => e.toJson()).toList()),
  );
}
