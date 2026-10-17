import 'job_activity_sync.dart';
import 'job_tracker.dart';
import 'live_progress.dart';

/// Follows the long jobs of one open server, in the app and on the lock
/// screen. Created when the server is opened, disposed when it is left.
class JobMonitor {
  JobMonitor({
    required JobSource source,
    required LiveProgress progress,
    required String instanceId,
    required String Function() serverName,
    required JobTexts Function() texts,
    required bool lockScreen,
  }) : tracker = JobTracker(source) {
    _sync = JobActivitySync(
      progress: progress,
      tracker: tracker,
      serverName: serverName,
      texts: texts,
      idPrefix: '$instanceId:',
      enabled: lockScreen,
    );
  }

  final JobTracker tracker;
  late final JobActivitySync _sync;

  void start() {
    _sync.start();
    tracker.start();
  }

  /// Whether the lock screen shows the jobs (the user's setting).
  Future<void> setLockScreen(bool on) => _sync.setEnabled(on);

  /// Looks again now, as when the app comes back to the foreground.
  Future<void> refresh() => tracker.refresh();

  Future<void> dispose() async {
    await _sync.dispose();
    await tracker.dispose();
  }
}
