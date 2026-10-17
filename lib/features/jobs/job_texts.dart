import '../../core/jobs/job_activity_sync.dart';
import '../../core/jobs/tracked_job.dart';
import '../../l10n/generated/app_localizations.dart';

extension JobKindText on AppLocalizations {
  String jobKindName(JobKind kind) => switch (kind) {
    JobKind.scrub => jobKindScrub,
    JobKind.replication => jobKindReplication,
    JobKind.appUpdate => jobKindAppUpdate,
    JobKind.cloudSync => jobKindCloudSync,
    JobKind.cloudBackup => jobKindCloudBackup,
    JobKind.rsync => jobKindRsync,
    JobKind.systemUpdate => jobKindSystemUpdate,
  };

  /// The words for the lock screen.
  JobTexts get jobTexts => JobTexts(
    kind: jobKindName,
    waiting: jobStateWaiting,
    running: jobStateRunning,
    done: jobStateSuccess,
    failed: jobStateFailed,
    aborted: jobStateAborted,
    stale: jobsStale,
    channelName: jobsChannelName,
    channelDescription: jobsChannelDescription,
  );
}
