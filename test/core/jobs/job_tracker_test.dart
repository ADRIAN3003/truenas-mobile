import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/jobs/job_tracker.dart';
import 'package:truenas_mobile/core/jobs/tracked_job.dart';
import 'package:truenas_mobile/core/models/job.dart';

import '../../support/job_fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('TrackedJob.of', () {
    test('knows scrubs, replications, app updates and the like', () {
      JobKind? kind(String method, [List<Object?>? args]) => TrackedJob.of(
        TrueNasJob.fromJson(jobJson(1, method, arguments: args)),
      )?.kind;
      expect(kind('pool.scrub.run'), JobKind.scrub);
      expect(kind('replication.run'), JobKind.replication);
      expect(kind('app.upgrade'), JobKind.appUpdate);
      expect(kind('cloudsync.sync'), JobKind.cloudSync);
      expect(kind('cloud_backup.sync'), JobKind.cloudBackup);
      expect(kind('rsynctask.run'), JobKind.rsync);
      expect(kind('update.run'), JobKind.systemUpdate);
      expect(kind('pool.dataset.create'), isNull);
    });

    test('names the pool of a scrub and the app of an update', () {
      final scrub = TrackedJob.of(
        TrueNasJob.fromJson(jobJson(1, 'pool.scrub.run', arguments: ['tank'])),
      );
      final app = TrackedJob.of(
        TrueNasJob.fromJson(jobJson(2, 'app.upgrade', arguments: ['plex', {}])),
      );
      expect(scrub?.target, 'tank');
      expect(app?.target, 'plex');
    });

    test('counts "update all apps" (core.bulk) as an app update', () {
      final bulk = TrackedJob.of(
        TrueNasJob.fromJson(
          jobJson(
            3,
            'core.bulk',
            arguments: [
              'app.upgrade',
              [
                ['plex', {}],
                ['nextcloud', {}],
              ],
            ],
          ),
        ),
      );
      expect(bulk?.kind, JobKind.appUpdate);
      expect(bulk?.target, isNull);
      expect(
        TrackedJob.of(
          TrueNasJob.fromJson(
            jobJson(4, 'core.bulk', arguments: ['pool.dataset.delete', []]),
          ),
        ),
        isNull,
      );
    });
  });

  group('JobTracker', () {
    late FakeJobSource source;
    late JobTracker tracker;

    setUp(() {
      source = FakeJobSource();
      tracker = JobTracker(
        source,
        pollInterval: const Duration(milliseconds: 50),
        linger: const Duration(milliseconds: 100),
      );
    });

    tearDown(() => tracker.dispose());

    test('finds jobs that already run and skips the others', () async {
      source.active.addAll([
        jobJson(1, 'pool.scrub.run', percent: 12, arguments: ['tank']),
        jobJson(2, 'zfs.snapshot.create'),
      ]);
      tracker.start();
      await settle();
      expect(tracker.snapshot.jobs.map((t) => t.id), [1]);
      expect(tracker.snapshot.jobs.single.job.percent, 12);
      expect(tracker.snapshot.connected, isTrue);
    });

    test('follows progress events and the end of a job', () async {
      source.active.add(jobJson(1, 'replication.run', percent: 5));
      tracker.start();
      await settle();

      source.emit('changed', 1, {
        'progress': {'percent': 60.5, 'description': 'Sending tank/data'},
      });
      await settle();
      final job = tracker.snapshot.jobs.single.job;
      expect(job.percent, 60.5);
      expect(job.progressText, 'Sending tank/data');
      expect(job.method, 'replication.run');

      source.emit('changed', 1, {'state': 'SUCCESS'});
      await settle();
      expect(tracker.snapshot.jobs.single.job.state, JobState.success);

      // A finished job stays for a moment, then goes.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(tracker.snapshot.jobs, isEmpty);
    });

    test('picks up a job that starts after the screen opened', () async {
      tracker.start();
      await settle();
      source.emit('added', 9, jobJson(9, 'app.upgrade', arguments: ['plex']));
      await settle();
      expect(tracker.snapshot.jobs.single.target, 'plex');
    });

    test('ignores events of jobs it does not follow', () async {
      tracker.start();
      await settle();
      source.emit('added', 5, jobJson(5, 'filesystem.chown'));
      source.emit('changed', 5, {'state': 'SUCCESS'});
      await settle();
      expect(tracker.snapshot.jobs, isEmpty);
      // Only the first refresh asked the server.
      expect(source.activeCalls, 1);
    });

    test('looks up a job whose start it missed', () async {
      tracker.start();
      await settle();
      source.active.add(jobJson(4, 'pool.scrub.run', percent: 50));
      source.emit('changed', 4, {
        'progress': {'percent': 51, 'description': ''},
      });
      await settle();
      expect(tracker.snapshot.jobs.single.job.percent, 51);
    });

    test('takes the last state of a job that ended unseen', () async {
      source.active.add(jobJson(1, 'pool.scrub.run', percent: 90));
      tracker.start();
      await settle();
      source.active.clear();
      source.finished[1] = jobJson(1, 'pool.scrub.run', state: 'SUCCESS');
      source.reconnect();
      await settle();
      expect(tracker.snapshot.jobs.single.job.state, JobState.success);
    });

    test('marks the numbers old while the server cannot be reached', () async {
      source.active.add(jobJson(1, 'pool.scrub.run', percent: 30));
      tracker.start();
      await settle();
      source.offline = true;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(tracker.snapshot.connected, isFalse);
      expect(tracker.snapshot.jobs.single.job.percent, 30);

      source.offline = false;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(tracker.snapshot.connected, isTrue);
    });

    test('does not ask again while nothing runs', () async {
      tracker.start();
      await settle();
      final calls = source.activeCalls;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(source.activeCalls, calls);
    });
  });
}
