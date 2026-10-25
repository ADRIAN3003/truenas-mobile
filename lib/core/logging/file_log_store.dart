import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'app_log.dart';

/// The log as a file with one JSON entry per line, so a second isolate (the
/// background check) can append to it while the app is open.
class FileLogStore implements LogStore {
  const FileLogStore(this.file);

  final File file;

  @override
  Future<List<LogEntry>> load() async {
    if (!await file.exists()) return [];
    return [
      for (final line in await file.readAsLines()) ?LogEntry.tryParse(line),
    ];
  }

  @override
  Future<void> append(LogEntry entry) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${entry.toJsonLine()}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  @override
  Future<void> rewrite(List<LogEntry> entries) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      entries.map((e) => '${e.toJsonLine()}\n').join(),
      flush: true,
    );
  }
}

/// Keeps [AppLog.instance] in a file in the app's own storage. Safe to call
/// in the background isolate too. Never throws.
Future<void> attachLogFile() async {
  try {
    final dir = await getApplicationSupportDirectory();
    await AppLog.instance.attach(FileLogStore(File('${dir.path}/app.log')));
  } catch (_) {}
}

/// Sends what the app does not catch itself to [AppLog.instance]: errors the
/// framework reports and errors that escape an async call. The previous
/// handlers still run, so nothing changes on the console.
void logUncaughtErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLog.instance.error('flutter', details.exception, details.stack);
    previous?.call(details);
  };
  final previousDispatcher = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.instance.error('uncaught', error, stack);
    return previousDispatcher?.call(error, stack) ?? false;
  };
}
