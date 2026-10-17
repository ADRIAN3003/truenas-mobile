import '../models/job.dart';

/// The long-running jobs the app shows live progress for.
enum JobKind {
  scrub,
  replication,
  appUpdate,
  cloudSync,
  cloudBackup,
  rsync,
  systemUpdate;

  /// The kind of [method], or null for a job the app does not follow.
  static JobKind? ofMethod(String method) {
    if (method.startsWith('pool.scrub')) return scrub;
    if (method.startsWith('replication.run')) return replication;
    if (method.startsWith('app.') && method.contains('upgrade')) {
      return appUpdate;
    }
    return switch (method) {
      'cloudsync.sync' => cloudSync,
      'cloud_backup.sync' => cloudBackup,
      'rsynctask.run' => rsync,
      'update.update' || 'update.run' || 'update.download' => systemUpdate,
      _ => null,
    };
  }
}

/// A job the app follows, with what kind of work it is.
class TrackedJob {
  const TrackedJob(this.job, this.kind, {this.target});

  /// [job] as a tracked job, or null when it is not one of [JobKind].
  ///
  /// `core.bulk` runs another method for many items in one job (the "update
  /// all apps" button); it counts as the method it runs.
  static TrackedJob? of(TrueNasJob job) {
    final arguments = job.raw['arguments'];
    final first = arguments is List && arguments.isNotEmpty
        ? arguments.first
        : null;
    final method = job.method == 'core.bulk' && first is String
        ? first
        : job.method;
    final kind = JobKind.ofMethod(method);
    if (kind == null) return null;
    // The pool of a scrub and the app being updated are the first argument.
    final named =
        job.method != 'core.bulk' &&
        (kind == JobKind.scrub || kind == JobKind.appUpdate);
    return TrackedJob(
      job,
      kind,
      target: named && first is String ? first : null,
    );
  }

  final TrueNasJob job;
  final JobKind kind;

  /// What the job works on (a pool or an app), when the server says.
  final String? target;

  int get id => job.id;

  TrackedJob withJob(TrueNasJob next) => TrackedJob(next, kind, target: target);
}
