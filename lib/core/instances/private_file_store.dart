import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Values kept as files in the app's own storage, one file per key, so the
/// app and the background check (another isolate) can write different keys
/// at the same time without overwriting each other.
///
/// Only Android's app sandbox protects them: no other app can read them, but
/// anyone with root can. Android uses this instead of the Keystore because
/// some phones (a custom ROM, root) lose the Keystore key at a restart, and
/// with it everything encrypted under it.
class PrivateFileStore {
  const PrivateFileStore([this._directory = _defaultDirectory]);

  final Future<Directory> Function() _directory;

  static Future<Directory> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/$folderName');
  }

  /// The folder inside the app's files directory. The backup rules exclude
  /// it by this name, so keep both in step.
  static const folderName = 'private_store';

  /// The value of [key], or null when it was never written.
  Future<String?> read(String key) async {
    final file = await _file(key);
    return await file.exists() ? file.readAsString() : null;
  }

  /// Replaces the value of [key]. The new content is written next to the old
  /// file and moved over it, so a crash never leaves half a value.
  Future<void> write(String key, String value) async {
    final file = await _file(key);
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(value, flush: true);
    await temp.rename(file.path);
  }

  Future<void> delete(String key) async {
    final file = await _file(key);
    if (await file.exists()) await file.delete();
  }

  /// Whether a file for [key] exists.
  Future<bool> contains(String key) async => (await _file(key)).exists();

  /// Removes every value.
  Future<void> deleteAll() async {
    final dir = await _directory();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<File> _file(String key) async =>
      File('${(await _directory()).path}/${_fileName(key)}');

  /// Keys are plain words with dots today; anything else is percent-encoded
  /// so a key can never point outside the folder.
  static String _fileName(String key) => key.replaceAllMapped(
    RegExp(r'[^A-Za-z0-9._-]'),
    (m) => '%${m[0]!.codeUnitAt(0).toRadixString(16).padLeft(2, '0')}',
  );
}
