import '../jobs/tracked_job.dart';
import '../models/job.dart';
import '../session/truenas_session.dart';

/// The kinds of job a notification is worth it for: the long ones that run
/// by themselves, on a schedule or on a tap, and that nobody sits and watches.
const watchedJobKinds = {
  JobKind.scrub,
  JobKind.replication,
  JobKind.cloudSync,
  JobKind.cloudBackup,
  JobKind.rsync,
};

/// What the background check knew of one server's jobs the last time.
class JobWatchState {
  const JobWatchState(this.maxId, this.active);

  factory JobWatchState.fromJson(Map<String, dynamic> json) => JobWatchState(
    (json['max'] as num).toInt(),
    {for (final id in json['active'] as List<dynamic>) (id as num).toInt()},
  );

  /// The highest job id seen. Every job above it is new.
  final int maxId;

  /// Watched jobs that were waiting or running, so that their end is noticed
  /// even though their id is below [maxId].
  final Set<int> active;

  Map<String, dynamic> toJson() => {'max': maxId, 'active': active.toList()};
}

/// What a look at the jobs of a server found.
class JobWatchResult {
  const JobWatchResult(this.state, this.finished);

  final JobWatchState state;

  /// Watched jobs that finished (done or failed) since the last look, oldest
  /// first. Empty on the first look at a server: what ended before is not
  /// news.
  final List<TrackedJob> finished;
}

/// Looks at a server's jobs and says which watched ones ended since [before].
///
/// A job that started and ended between two looks is found as a new job; one
/// that was running at the last look is asked for by id. Aborted jobs are not
/// reported (somebody did that on purpose), and neither is a job that ended
/// longer than [maxAge] ago, such as after the phone was off for days.
Future<JobWatchResult> watchJobs(
  TrueNasSession session,
  JobWatchState? before, {
  DateTime? now,
  Duration maxAge = const Duration(hours: 24),
}) async {
  if (before == null) {
    final active = [
      for (final job in await session.activeJobs())
        if (_watched(job)) job,
    ];
    final newest = await session.jobs(limit: 1);
    return JobWatchResult(
      JobWatchState(_highest(0, [...active, ...newest]), {
        for (final job in active) job.id,
      }),
      const [],
    );
  }
  var floor = before.maxId;
  var remembered = before.active;
  var fresh = await session.jobsAfter(floor);
  // Job ids start again from 1 when the middleware restarts (a reboot), so
  // nothing would be above the old highest id for a long time. Every job the
  // server lists then started after the last look, and the remembered ids
  // belong to jobs that are gone (or to new ones that reuse them).
  if (fresh.isEmpty && await _restarted(session, floor)) {
    floor = 0;
    remembered = const {};
    fresh = await session.jobsAfter(0);
  }
  final earlier = remembered.isEmpty
      ? const <TrueNasJob>[]
      : await session.jobsById(remembered);
  final all = [...earlier, ...fresh]..sort((a, b) => a.id.compareTo(b.id));
  final active = <int>{};
  final finished = <TrackedJob>[];
  final cutoff = (now ?? DateTime.now()).subtract(maxAge);
  for (final job in all) {
    if (!_watched(job)) continue;
    final tracked = TrackedJob.of(job)!;
    if (job.state.isActive) {
      active.add(job.id);
    } else if (job.state != JobState.aborted &&
        (job.finished == null || job.finished!.isAfter(cutoff))) {
      finished.add(tracked);
    }
  }
  // A job the server no longer lists (purged) is forgotten.
  return JobWatchResult(JobWatchState(_highest(floor, all), active), finished);
}

/// Whether the newest job the server lists is older than [maxId], which only
/// happens when its ids started again.
Future<bool> _restarted(TrueNasSession session, int maxId) async {
  final newest = await session.jobs(limit: 1);
  return newest.isNotEmpty && newest.first.id < maxId;
}

bool _watched(TrueNasJob job) {
  final tracked = TrackedJob.of(job);
  return tracked != null && watchedJobKinds.contains(tracked.kind);
}

int _highest(int from, Iterable<TrueNasJob> jobs) {
  var highest = from;
  for (final job in jobs) {
    if (job.id > highest) highest = job.id;
  }
  return highest;
}
