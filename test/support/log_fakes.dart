import 'dart:ui' show Rect;

import 'package:truenas_mobile/core/logging/app_log.dart';
import 'package:truenas_mobile/core/logging/log_providers.dart';

/// A log store in memory. [failWrites] makes it throw, like a full disk.
class MemoryLogStore implements LogStore {
  MemoryLogStore([List<LogEntry> initial = const []]) : entries = [...initial];

  final List<LogEntry> entries;
  var failWrites = false;

  @override
  Future<List<LogEntry>> load() async => [...entries];

  @override
  Future<void> append(LogEntry entry) async {
    if (failWrites) throw StateError('disk full');
    entries.add(entry);
  }

  @override
  Future<void> rewrite(List<LogEntry> next) async {
    if (failWrites) throw StateError('disk full');
    entries
      ..clear()
      ..addAll(next);
  }
}

/// Remembers what the share sheet would have been given.
class FakeLogSharer implements LogSharer {
  final shared = <String>[];
  var fail = false;

  @override
  Future<void> share(String text, {Rect? origin}) async {
    if (fail) throw StateError('no share sheet');
    shared.add(text);
  }
}
