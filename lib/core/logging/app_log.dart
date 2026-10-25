import 'dart:async';
import 'dart:convert';

import 'log_redaction.dart';

enum LogLevel { info, warning, error }

/// One line of the error log. [message] and [details] are already scrubbed
/// of secrets (see [redactSecrets]).
class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.source,
    required this.message,
    this.details,
  });

  /// Null for a line that is damaged or from an unknown version.
  static LogEntry? tryParse(String line) {
    try {
      final json = jsonDecode(line);
      if (json is! Map<String, dynamic>) return null;
      final time = DateTime.tryParse(json['t'] as String? ?? '');
      final message = json['m'];
      if (time == null || message is! String) return null;
      return LogEntry(
        time: time,
        level: LogLevel.values.asNameMap()[json['l']] ?? LogLevel.error,
        source: json['s'] as String? ?? '',
        message: message,
        details: json['d'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  final DateTime time;
  final LogLevel level;

  /// The part of the app it came from: `rpc`, `connect`, `flutter`...
  final String source;
  final String message;

  /// A stack trace, when there is one.
  final String? details;

  String toJsonLine() => jsonEncode({
    't': time.toUtc().toIso8601String(),
    'l': level.name,
    's': source,
    'm': message,
    if (details != null) 'd': details,
  });

  /// The entry as plain text, for copying and sharing.
  String format() {
    final head =
        '${time.toUtc().toIso8601String()} ${level.name.toUpperCase()} '
        '[$source] $message';
    if (details == null) return head;
    final indented = details!.trimRight().split('\n').map((l) => '    $l');
    return '$head\n${indented.join('\n')}';
  }
}

/// Where the log is kept between runs.
abstract interface class LogStore {
  Future<List<LogEntry>> load();
  Future<void> append(LogEntry entry);

  /// Replaces everything with [entries].
  Future<void> rewrite(List<LogEntry> entries);
}

/// The app-wide log of what went wrong: uncaught errors, failed connections
/// and sign-ins, calls the server refused. It is kept on the phone only
/// (never sent anywhere) and can be copied or shared from Settings.
///
/// Anything written is scrubbed of passwords, tokens and keys first, and
/// logging itself never throws. Call parameters are never logged, only the
/// method and what the server answered.
class AppLog {
  AppLog({this.capacity = 500, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// The log of this isolate. It lives in memory until [attach] gives it a
  /// store; the background check runs in its own isolate with its own copy,
  /// and both write to the same file.
  static AppLog instance = AppLog();

  /// How many entries are kept; the oldest go first.
  final int capacity;
  final DateTime Function() _clock;

  static const _maxMessage = 2000;
  static const _maxStackLines = 30;

  /// The same line again within this time is not written twice, so a socket
  /// that keeps failing cannot push everything else out.
  static const _duplicateWindow = Duration(seconds: 5);

  var _entries = <LogEntry>[];
  LogStore? _store;
  Future<void> _writes = Future.value();
  final _changes = StreamController<void>.broadcast();

  /// Oldest first.
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Fires when entries were added, removed or reloaded.
  Stream<void> get changes => _changes.stream;

  /// Starts keeping the log in [store]: what it holds is loaded, anything
  /// logged so far is added to it.
  Future<void> attach(LogStore store) async {
    try {
      final stored = await store.load();
      final early = _entries;
      _entries = _trimmed([...stored, ...early]);
      _store = store;
      if (early.isNotEmpty || stored.length > capacity) {
        await store.rewrite(_entries);
      }
      _changes.add(null);
    } catch (_) {
      // Without a store the log stays in memory.
    }
  }

  /// Reads the store again, to pick up what the background check wrote.
  Future<void> reload() async {
    final store = _store;
    if (store == null) return;
    try {
      await _writes;
      _entries = _trimmed(await store.load());
      _changes.add(null);
    } catch (_) {}
  }

  void info(String source, String message) =>
      record(LogLevel.info, source, message);

  void warning(String source, String message) =>
      record(LogLevel.warning, source, message);

  /// Logs [error] (and its [stack]) at the error level.
  void error(String source, Object error, [StackTrace? stack]) =>
      record(LogLevel.error, source, error.toString(), stack: stack);

  void record(
    LogLevel level,
    String source,
    String message, {
    StackTrace? stack,
  }) {
    try {
      final now = _clock();
      final entry = LogEntry(
        time: now,
        level: level,
        source: source,
        message: _clip(redactSecrets(message)),
        details: stack == null ? null : _stackText(stack),
      );
      final last = _entries.isEmpty ? null : _entries.last;
      if (last != null &&
          last.level == entry.level &&
          last.source == entry.source &&
          last.message == entry.message &&
          now.difference(last.time).abs() < _duplicateWindow) {
        return;
      }
      _entries = _trimmed([..._entries, entry]);
      final store = _store;
      if (store != null) {
        _writes = _writes
            .then((_) => store.append(entry))
            .catchError((Object _) {});
      }
      _changes.add(null);
    } catch (_) {}
  }

  /// Empties the log, here and in the store.
  Future<void> clear() async {
    _entries = [];
    _changes.add(null);
    final store = _store;
    if (store == null) return;
    _writes = _writes
        .then((_) => store.rewrite(const []))
        .catchError((Object _) {});
    await _writes;
  }

  /// Completes when everything logged so far is in the store.
  Future<void> flush() => _writes;

  /// The whole log as text, oldest first, after an optional [header].
  String export({String header = ''}) {
    final body = _entries.map((e) => e.format()).join('\n');
    return header.isEmpty ? body : '$header\n\n$body';
  }

  List<LogEntry> _trimmed(List<LogEntry> all) =>
      all.length <= capacity ? all : all.sublist(all.length - capacity);

  static String _clip(String text) => text.length <= _maxMessage
      ? text
      : '${text.substring(0, _maxMessage)}...';

  static String _stackText(StackTrace stack) {
    final lines = stack.toString().trimRight().split('\n');
    final kept = lines.take(_maxStackLines).join('\n');
    return redactSecrets(lines.length > _maxStackLines ? '$kept\n...' : kept);
  }
}
