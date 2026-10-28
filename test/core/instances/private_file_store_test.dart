import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/private_file_store.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// The old secure storage, as the plugin answers on the platform channel.
class _OldStorage {
  final values = <String, String>{};
  var broken = false;
  final calls = <String>[];

  Future<Object?> handle(MethodCall call) async {
    final args = call.arguments as Map;
    calls.add('${call.method} ${args['key']}');
    if (broken) {
      throw PlatformException(
        code: 'Exception encountered',
        message: 'Migration failed after algorithm change',
      );
    }
    switch (call.method) {
      case 'read':
        return values[args['key']];
      case 'delete':
        values.remove(args['key']);
        return null;
      case 'write':
        values[args['key'] as String] = args['value'] as String;
        return null;
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late PrivateFileStore files;
  late _OldStorage old;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('private_store_test');
    files = PrivateFileStore(() async => dir);
    old = _OldStorage();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, old.handle);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('PrivateFileStore', () {
    test('keeps a value per key and replaces it', () async {
      expect(await files.read('a.v1'), isNull);
      await files.write('a.v1', 'one');
      await files.write('b.v1', 'two');
      await files.write('a.v1', 'three');
      expect(await files.read('a.v1'), 'three');
      expect(await files.read('b.v1'), 'two');
      expect(dir.listSync().whereType<File>().length, 2);
    });

    test('a key cannot reach outside the folder', () async {
      await files.write('../evil', 'x');
      expect(await files.read('../evil'), 'x');
      expect(dir.parent.listSync().any((e) => e.path.endsWith('evil')), false);
    });

    test('deleteAll empties it', () async {
      await files.write('a', '1');
      await files.deleteAll();
      expect(await files.read('a'), isNull);
    });
  });

  group('SecureKeyValueStore on Android', () {
    SecureKeyValueStore store() =>
        SecureKeyValueStore(const FlutterSecureStorage(), files);

    test('a fresh phone reads nothing and saves to the file', () async {
      expect(await store().read('servers.v1'), isNull);
      await store().write('servers.v1', '[]');
      expect(await store().read('servers.v1'), '[]');
      expect(await files.read('servers.v1'), '[]');
    });

    test('a value in the old storage is moved over once', () async {
      old.values['servers.v1'] = '[{"id":"a"}]';
      expect(await store().read('servers.v1'), '[{"id":"a"}]');
      expect(await files.read('servers.v1'), '[{"id":"a"}]');
      expect(old.values, isEmpty, reason: 'the old copy is removed');

      old.calls.clear();
      expect(await store().read('servers.v1'), '[{"id":"a"}]');
      expect(old.calls, isEmpty, reason: 'the old storage is not asked again');
    });

    test('a key absent from the old storage is not asked for twice', () async {
      expect(await store().read('settings.v1'), isNull);
      old.calls.clear();
      expect(await store().read('settings.v1'), isNull);
      expect(old.calls, isEmpty);
    });

    test('an unreadable old storage is an error, nothing is marked', () async {
      old.values['servers.v1'] = 'secret';
      old.broken = true;
      await expectLater(
        store().read('servers.v1'),
        throwsA(isA<PlatformException>()),
      );
      expect(await files.contains('servers.v1.moved'), isFalse);

      // It comes back later: the value is still there to move.
      old.broken = false;
      expect(await store().read('servers.v1'), 'secret');
    });

    test('writing works when the old storage is broken for good', () async {
      old.broken = true;
      await store().write('servers.v1', '[]');
      old.calls.clear();
      expect(await store().read('servers.v1'), '[]');
      expect(old.calls, isEmpty);
    });

    test('reset clears the files', () async {
      await store().write('servers.v1', '[]');
      old.broken = false;
      await store().reset();
      expect(await files.read('servers.v1'), isNull);
    });
  });
}
