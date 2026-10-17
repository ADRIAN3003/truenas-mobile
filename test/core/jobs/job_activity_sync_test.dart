import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/jobs/job_activity_sync.dart';
import 'package:truenas_mobile/core/jobs/job_tracker.dart';
import 'package:truenas_mobile/core/jobs/live_progress.dart';
import 'package:truenas_mobile/core/jobs/tracked_job.dart';

import '../../support/job_fakes.dart';

Future<void> settle([int ms = 30]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

const texts = JobTexts(
  kind: _kindName,
  waiting: 'Waiting',
  running: 'Running',
  done: 'Done',
  failed: 'Failed',
  aborted: 'Aborted',
  stale: 'Not updating',
  channelName: 'Job progress',
  channelDescription: 'Progress of jobs',
);

String _kindName(JobKind kind) => kind.name;

void main() {
  late FakeJobSource source;
  late FakeLiveProgress progress;
  late JobTracker tracker;
  late JobActivitySync sync;

  void build({
    bool supported = true,
    bool enabled = true,
    Duration minGap = Duration.zero,
    Duration heartbeat = const Duration(minutes: 1),
  }) {
    source = FakeJobSource();
    progress = FakeLiveProgress(supported: supported);
    tracker = JobTracker(
      source,
      pollInterval: const Duration(milliseconds: 40),
      linger: const Duration(seconds: 5),
    );
    sync = JobActivitySync(
      progress: progress,
      tracker: tracker,
      serverName: () => 'Home NAS',
      texts: () => texts,
      idPrefix: 'srv:',
      enabled: enabled,
      minGap: minGap,
      heartbeat: heartbeat,
    );
    sync.start();
  }

  tearDown(() async {
    await sync.dispose();
    await tracker.dispose();
  });

  test('shows a running job and its progress', () async {
    build();
    source.active.add(
      jobJson(
        1,
        'pool.scrub.run',
        percent: 25,
        text: 'Scanning',
        arguments: ['tank'],
      ),
    );
    tracker.start();
    await settle();

    final first = progress.shown.single;
    expect(first.id, 'srv:1');
    expect(first.title, 'scrub · tank');
    expect(first.server, 'Home NAS');
    expect(first.detail, 'Scanning');
    expect(first.progress, 0.25);
    expect(first.status, LiveStatus.running);
    expect(first.statusLabel, 'Running');
    expect(progress.permissionAsked, 1);

    source.emit('changed', 1, {
      'progress': {'percent': 26.4, 'description': 'Scanning'},
    });
    await settle();
    expect(progress.shown.last.progress, closeTo(0.264, 1e-9));
  });

  test('skips an update that changes nothing the lock screen shows', () async {
    build();
    source.active.add(jobJson(1, 'pool.scrub.run', percent: 25.1, text: 'a'));
    tracker.start();
    await settle();
    source.emit('changed', 1, {
      'progress': {'percent': 25.9, 'description': 'a'},
    });
    await settle();
    expect(progress.shown, hasLength(1));
  });

  test(
    'sends at most one update per gap, and the last value after it',
    () async {
      build(minGap: const Duration(milliseconds: 150));
      source.active.add(jobJson(1, 'pool.scrub.run', percent: 10, text: 'a'));
      tracker.start();
      await settle();
      for (final percent in [11, 12, 13]) {
        source.emit('changed', 1, {
          'progress': {'percent': percent, 'description': 'a'},
        });
      }
      await settle();
      expect(progress.shown, hasLength(1));
      await settle(200);
      expect(progress.shown, hasLength(2));
      expect(progress.shown.last.progress, 0.13);
    },
  );

  test('leaves the result of a finished job on the lock screen', () async {
    build();
    source.active.add(jobJson(1, 'replication.run', percent: 80));
    tracker.start();
    await settle();
    source.emit('changed', 1, {'state': 'FAILED', 'error': 'Boom\nstack'});
    await settle();
    final last = progress.shown.last;
    expect(last.status, LiveStatus.failed);
    expect(last.detail, 'Boom');
    expect(last.isFinal, isTrue);
    expect(progress.ended, isEmpty);
  });

  test('says so when the server cannot be reached', () async {
    build();
    source.active.add(jobJson(1, 'pool.scrub.run', percent: 40));
    tracker.start();
    await settle();
    source.offline = true;
    await settle(120);
    final last = progress.shown.last;
    expect(last.status, LiveStatus.stale);
    expect(last.detail, 'Not updating');
    expect(last.progress, 0.4);
  });

  test(
    'removes activities left by an earlier run, but not current jobs',
    () async {
      build();
      source.active.add(jobJson(2, 'pool.scrub.run', percent: 1));
      tracker.start();
      await settle();
      expect(progress.keptOnReconcile, [
        {'srv:2'},
      ]);
    },
  );

  test('removes the activity of a running job when it is let go', () async {
    build();
    source.active.add(jobJson(1, 'pool.scrub.run', percent: 1));
    tracker.start();
    await settle();
    await sync.dispose();
    expect(progress.ended, ['srv:1']);
  });

  test('does nothing where the phone has no Live Activities', () async {
    build(supported: false);
    source.active.add(jobJson(1, 'pool.scrub.run', percent: 1));
    tracker.start();
    await settle();
    expect(progress.shown, isEmpty);
    expect(progress.permissionAsked, 0);
  });

  test('can be switched off and on again', () async {
    build();
    source.active.add(jobJson(1, 'pool.scrub.run', percent: 1));
    tracker.start();
    await settle();
    await sync.setEnabled(false);
    expect(progress.ended, ['srv:1']);
    final before = progress.shown.length;
    source.emit('changed', 1, {
      'progress': {'percent': 50, 'description': ''},
    });
    await settle();
    expect(progress.shown.length, before);
    await sync.setEnabled(true);
    await settle();
    expect(progress.shown.last.progress, 0.5);
  });

  test('repeats itself now and then while a job runs', () async {
    build(heartbeat: const Duration(milliseconds: 60));
    source.active.add(jobJson(1, 'pool.scrub.run', percent: 5));
    tracker.start();
    await settle(200);
    expect(progress.shown.length, greaterThan(1));
  });
}
