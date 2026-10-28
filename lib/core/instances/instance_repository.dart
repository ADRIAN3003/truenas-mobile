import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logging/app_log.dart';
import '../logging/log_redaction.dart';
import 'private_file_store.dart';
import 'server_instance.dart';

/// Minimal key-value storage, so tests can swap out secure storage.
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);

  /// Erases everything in the store, including a Keystore key that no longer
  /// works. Only for starting over after the store cannot be used at all.
  Future<void> reset();
}

/// Where the app keeps what must survive a restart of the phone: the saved
/// servers (with their passwords or API keys), settings and the background
/// check's bookkeeping.
///
/// iOS keeps them in the Keychain. Android keeps them in a private file of the
/// app ([PrivateFileStore]), because the Keystore key behind
/// `flutter_secure_storage` is lost at a restart on some phones (a custom ROM
/// with root, seen on LineageOS) and everything saved under it with it. A key
/// is moved over from that storage the first time it is read; what the old
/// storage cannot read any more is an error, never "nothing saved", so the
/// caller does not save over it.
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
    this._files,
  ]);

  final FlutterSecureStorage _storage;

  /// The Android file store; null means the default one on Android and none
  /// elsewhere.
  final PrivateFileStore? _files;

  static const _androidFiles = PrivateFileStore();

  PrivateFileStore? get _private =>
      _files ?? (Platform.isAndroid ? _androidFiles : null);

  /// Same store, but allowed to throw away what it cannot decrypt. The
  /// plugin only erases and starts again from `resetOnError`, and the normal
  /// store has it off so that a read which fails for a moment loses nothing.
  static const _eraser = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
      migrateOnAlgorithmChange: false,
    ),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// The marker that says the old storage has been dealt with for [key].
  static String _movedMark(String key) => '$key.moved';

  @override
  Future<String?> read(String key) async {
    final files = _private;
    if (files == null) return _storage.read(key: key);
    final own = await files.read(key);
    if (own != null) return own;
    if (await files.contains(_movedMark(key))) return null;

    // First read on this phone: take over what the old storage holds. If it
    // cannot be read this throws and nothing is marked, so a later try (or
    // Clear) starts from the same place.
    final old = await _storage.read(key: key);
    if (old != null) await files.write(key, old);
    await files.write(_movedMark(key), '');
    if (old != null) await _forgetOld(key);
    return old;
  }

  @override
  Future<void> write(String key, String value) async {
    final files = _private;
    if (files == null) return _storage.write(key: key, value: value);
    await files.write(key, value);
    if (!await files.contains(_movedMark(key))) {
      await files.write(_movedMark(key), '');
      await _forgetOld(key);
    }
  }

  /// The old copy of [key] goes, so a password is not kept in two places.
  /// Failing to remove it changes nothing: the file is read first.
  Future<void> _forgetOld(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  @override
  Future<void> reset() async {
    await _private?.deleteAll();
    await _eraser.deleteAll();
  }
}

/// One line on why the secure storage failed: a platform error's message
/// (the Java exception behind it on Android), cut to a readable length.
String storageErrorSummary(Object error) {
  final text = error is PlatformException
      ? error.message ?? error.code
      : error.toString();
  final line = redactSecrets(text.split('\n').first.trim());
  return line.length <= 240 ? line : '${line.substring(0, 240)}...';
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

  /// Starts over: every saved value goes, and a key that can no longer
  /// decrypt them with it. For when the store fails on every read and write.
  Future<void> reset() => _store.reset();

  /// Android's Keystore can fail for a moment (right after boot or an
  /// update), so a failed read is tried again, a little later each time,
  /// before it counts. What went wrong is logged, so the cause can be read
  /// in Settings > About > error log.
  Future<String?> _read() async {
    for (var attempt = 1; ; attempt++) {
      try {
        final raw = await _store.read(storageKey);
        if (attempt > 1) {
          AppLog.instance.warning(
            'storage',
            'Saved servers read on try $attempt',
          );
        }
        return raw;
      } catch (error, stack) {
        AppLog.instance.error(
          'storage',
          'Reading saved servers: $error',
          stack,
        );
        if (attempt == _readAttempts) rethrow;
        await Future<void>.delayed(retryDelay * attempt);
      }
    }
  }

  static const _readAttempts = 5;

  Future<void> save(List<ServerInstance> instances) => _store.write(
    storageKey,
    jsonEncode(instances.map((e) => e.toJson()).toList()),
  );
}
