import 'package:truenas_mobile/core/instances/instance_repository.dart';

class MemoryStore implements KeyValueStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// A store whose reads and writes fail while [failReads] / [failWrites] count
/// down, like a Keystore that is not ready yet.
class FlakyStore extends MemoryStore {
  int failReads = 0;
  int failWrites = 0;
  int reads = 0;

  @override
  Future<String?> read(String key) async {
    reads++;
    if (failReads > 0) {
      failReads--;
      throw StateError('Keystore not ready');
    }
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites > 0) {
      failWrites--;
      throw StateError('Keystore not ready');
    }
    return super.write(key, value);
  }
}
