import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_log.dart';

final appLogProvider = Provider<AppLog>((ref) => AppLog.instance);

/// The entries of the log, oldest first, again each time one is added.
final logEntriesProvider = StreamProvider.autoDispose<List<LogEntry>>((
  ref,
) async* {
  final log = ref.watch(appLogProvider);
  yield log.entries;
  await for (final _ in log.changes) {
    yield log.entries;
  }
});

/// Hands the log to the phone's share sheet. Tests replace it.
abstract interface class LogSharer {
  /// [origin] is where an iPad anchors the share popover.
  Future<void> share(String text, {Rect? origin});
}

/// Shares the log as a text file, which mail, messages and file apps take
/// better than a very long text.
class PlatformLogSharer implements LogSharer {
  const PlatformLogSharer();

  @override
  Future<void> share(String text, {Rect? origin}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/truenas-mobile-log.txt');
    await file.writeAsString(text, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/plain')],
        subject: 'TrueNAS Mobile log',
        sharePositionOrigin: origin,
      ),
    );
  }
}

final logSharerProvider = Provider<LogSharer>(
  (ref) => const PlatformLogSharer(),
);
