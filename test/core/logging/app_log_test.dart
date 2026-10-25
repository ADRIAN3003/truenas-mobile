import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/logging/app_log.dart';
import 'package:truenas_mobile/core/logging/file_log_store.dart';

import '../../support/log_fakes.dart';

void main() {
  var now = DateTime.utc(2026, 10, 25, 12);
  late AppLog log;

  setUp(() {
    now = DateTime.utc(2026, 10, 25, 12);
    log = AppLog(capacity: 3, clock: () => now);
  });

  test('records entries oldest first and keeps only the newest', () {
    for (var i = 1; i <= 5; i++) {
      now = now.add(const Duration(minutes: 1));
      log.warning('rpc', 'call $i failed');
    }
    expect(log.entries.map((e) => e.message), [
      'call 3 failed',
      'call 4 failed',
      'call 5 failed',
    ]);
  });

  test('scrubs secrets from the message and the stack trace', () {
    log.error(
      'connect',
      Exception('login failed, password: hunter2'),
      StackTrace.fromString('#0 login (token=abcdef)\n#1 main'),
    );
    final entry = log.entries.single;
    expect(entry.message, isNot(contains('hunter2')));
    expect(entry.details, isNot(contains('abcdef')));
    expect(entry.details, contains('#1 main'));
  });

  test('cuts a very long message and stack', () {
    log.warning('x', 'a' * 5000);
    log.error('x', 'boom', StackTrace.fromString('line\n' * 100));
    expect(log.entries.first.message.length, lessThan(2100));
    expect(log.entries.last.details!.split('\n').length, lessThan(35));
  });

  test('does not write the same line twice in a row within seconds', () {
    log.warning('rpc', 'same');
    now = now.add(const Duration(seconds: 2));
    log.warning('rpc', 'same');
    expect(log.entries, hasLength(1));
    now = now.add(const Duration(seconds: 10));
    log.warning('rpc', 'same');
    expect(log.entries, hasLength(2));
  });

  test('tells listeners about changes', () async {
    var changes = 0;
    log.changes.listen((_) => changes++);
    log.info('a', 'one');
    await log.clear();
    await pumpEventQueue();
    expect(changes, 2);
  });

  test('exports as text with the header first', () {
    log.warning('rpc', 'pool.query failed');
    log.error('flutter', 'boom', StackTrace.fromString('#0 a\n#1 b'));
    expect(
      log.export(header: 'TrueNAS Mobile log'),
      'TrueNAS Mobile log\n\n'
      '2026-10-25T12:00:00.000Z WARNING [rpc] pool.query failed\n'
      '2026-10-25T12:00:00.000Z ERROR [flutter] boom\n'
      '    #0 a\n'
      '    #1 b',
    );
  });

  group('store', () {
    test('keeps what was logged before it was attached', () async {
      log.warning('early', 'before the store');
      final store = MemoryLogStore([
        LogEntry(
          time: DateTime.utc(2026, 10, 24),
          level: LogLevel.error,
          source: 'old',
          message: 'last run',
        ),
      ]);
      await log.attach(store);
      expect(log.entries.map((e) => e.message), [
        'last run',
        'before the store',
      ]);
      expect(store.entries.map((e) => e.message), [
        'last run',
        'before the store',
      ]);
    });

    test('writes new entries through and clears the store', () async {
      final store = MemoryLogStore();
      await log.attach(store);
      log.warning('rpc', 'one');
      await log.flush();
      expect(store.entries.single.message, 'one');
      await log.clear();
      expect(log.entries, isEmpty);
      expect(store.entries, isEmpty);
    });

    test('reload picks up what another isolate wrote', () async {
      final store = MemoryLogStore();
      await log.attach(store);
      await store.append(
        LogEntry(
          time: now,
          level: LogLevel.warning,
          source: 'background',
          message: 'check failed',
        ),
      );
      await log.reload();
      expect(log.entries.single.source, 'background');
    });

    test('a store that fails never breaks logging', () async {
      final store = MemoryLogStore()..failWrites = true;
      await log.attach(store);
      log.warning('rpc', 'still logged');
      await log.flush();
      expect(log.entries.single.message, 'still logged');
    });

    test('trims a long stored log when it is attached', () async {
      final store = MemoryLogStore([
        for (var i = 0; i < 10; i++)
          LogEntry(
            time: now.add(Duration(minutes: i)),
            level: LogLevel.info,
            source: 's',
            message: 'm$i',
          ),
      ]);
      await log.attach(store);
      expect(log.entries.map((e) => e.message), ['m7', 'm8', 'm9']);
      expect(store.entries, hasLength(3));
    });
  });

  group('file store', () {
    late Directory dir;
    late FileLogStore store;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('applog');
      store = FileLogStore(File('${dir.path}/sub/app.log'));
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('round-trips entries, one per line', () async {
      await store.append(
        LogEntry(
          time: now,
          level: LogLevel.error,
          source: 'flutter',
          message: 'two\nlines',
          details: '#0 a',
        ),
      );
      await store.append(
        LogEntry(
          time: now,
          level: LogLevel.info,
          source: 'x',
          message: 'plain',
        ),
      );
      final loaded = await store.load();
      expect(loaded.map((e) => e.message), ['two\nlines', 'plain']);
      expect(loaded.first.level, LogLevel.error);
      expect(loaded.first.details, '#0 a');
      expect(loaded.first.time, now);
    });

    test('skips damaged lines and starts empty without a file', () async {
      expect(await store.load(), isEmpty);
      await store.rewrite(const []);
      await store.file.writeAsString(
        'not json\n{"t":"nope"}\n[1]\n',
        mode: FileMode.append,
      );
      await store.append(
        LogEntry(time: now, level: LogLevel.info, source: 's', message: 'ok'),
      );
      expect((await store.load()).map((e) => e.message), ['ok']);
    });
  });
}
