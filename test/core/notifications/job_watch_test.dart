import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/models/alert.dart';
import 'package:truenas_mobile/core/notifications/alert_watcher.dart';
import 'package:truenas_mobile/core/notifications/background_alerts.dart';
import 'package:truenas_mobile/core/settings/app_settings.dart';

import '../../support/alert_fakes.dart';
import '../../support/fake_truenas_server.dart';
import '../../support/job_fakes.dart';
import '../../support/memory_store.dart';

void main() {
  late FakeTrueNasServer server;
  late MemoryStore store;
  late FakeAlertNotifier notifier;
  late AlertWatcher watcher;

  setUp(() async {
    server = await FakeTrueNasServer.start();
    store = MemoryStore();
    notifier = FakeAlertNotifier();
    watcher = AlertWatcher(store: store, notifier: notifier);
  });
  tearDown(() => server.close());

  ServerInstance home({String id = '1'}) => ServerInstance(
    id: id,
    name: 'Home',
    url: 'http://127.0.0.1:${server.port}',
    authMethod: AuthMethod.password,
    username: 'truenas_admin',
    secret: 'secret',
  );

  Future<void> check({bool notify = true, bool notifyJobs = true}) =>
      watcher.check(
        [home()],
        minimum: AlertSeverity.critical,
        notify: notify,
        notifyJobs: notifyJobs,
      );

  Map<String, dynamic> job(
    int id,
    String method, {
    String state = 'SUCCESS',
    List<Object?>? arguments,
    String? error,
  }) => jobJson(id, method, state: state, arguments: arguments, error: error);

  test('the first look at a server does not announce old jobs', () async {
    server.jobs.add(job(200, 'pool.scrub.run', arguments: ['tank']));
    await check();
    expect(notifier.shownJobs, isEmpty);
  });

  test('a job that finished since the last look is announced once', () async {
    await check();
    server.jobs.add(job(200, 'pool.scrub.run', arguments: ['tank']));
    await check();
    expect(notifier.shownJobs, ['Home: job 200 done']);
    await check();
    expect(notifier.shownJobs, hasLength(1));
  });

  test('a job that was running is announced when it ends', () async {
    server.jobs.add(
      job(200, 'replication.run', state: 'RUNNING', arguments: [1]),
    );
    await check();
    await check();
    expect(notifier.shownJobs, isEmpty);

    server.jobs.single
      ..['state'] = 'FAILED'
      ..['error'] = '[EFAULT] connection refused';
    // A job that started later does not hide it.
    server.jobs.add(job(201, 'cloudsync.sync', state: 'RUNNING'));
    await check();
    expect(notifier.shownJobs, ['Home: job 200 failed']);

    server.jobs.last['state'] = 'SUCCESS';
    await check();
    expect(notifier.shownJobs, ['Home: job 200 failed', 'Home: job 201 done']);
  });

  test('a job that started and ended between two looks is found', () async {
    await check();
    server.jobs.add(job(200, 'cloudsync.sync', state: 'FAILED'));
    await check();
    expect(notifier.shownJobs, ['Home: job 200 failed']);
  });

  test(
    'jobs are still found after the NAS restarts and ids start over',
    () async {
      server.jobs.add(
        job(200, 'replication.run', state: 'RUNNING', arguments: [1]),
      );
      await check();
      // A reboot: the old jobs are gone and the new ones count from 1 again.
      server.jobs
        ..clear()
        ..add(job(3, 'pool.scrub.run', arguments: ['tank']));
      await check();
      expect(notifier.shownJobs, ['Home: job 3 done']);
      await check();
      expect(notifier.shownJobs, hasLength(1));
      server.jobs.add(job(4, 'cloudsync.sync', state: 'FAILED'));
      await check();
      expect(notifier.shownJobs, ['Home: job 3 done', 'Home: job 4 failed']);
    },
  );

  test(
    'other jobs, aborted ones and long finished ones are not news',
    () async {
      await check();
      server.jobs.addAll([
        job(200, 'update.run'),
        job(201, 'app.upgrade', arguments: ['plex']),
        job(202, 'pool.scrub.run', state: 'ABORTED'),
        job(203, 'filesystem.chown'),
        {
          ...job(204, 'pool.scrub.run'),
          'time_finished': {
            r'$date': DateTime.now()
                .subtract(const Duration(days: 3))
                .millisecondsSinceEpoch,
          },
        },
      ]);
      await check();
      expect(notifier.shownJobs, isEmpty);
    },
  );

  test(
    'a job that finishes while jobs are muted is not announced later',
    () async {
      await check();
      server.jobs.add(job(200, 'pool.scrub.run', arguments: ['tank']));
      await check(notifyJobs: false);
      await check();
      expect(notifier.shownJobs, isEmpty);
      server.jobs.add(job(201, 'pool.scrub.run', arguments: ['tank']));
      await check();
      expect(notifier.shownJobs, ['Home: job 201 done']);
    },
  );

  test('recording only (turning it on) stays quiet', () async {
    server.jobs.add(job(200, 'pool.scrub.run', arguments: ['tank']));
    await check(notify: false);
    server.jobs.add(job(201, 'pool.scrub.run', arguments: ['tank']));
    await check(notify: false);
    expect(notifier.shownJobs, isEmpty);
    await check();
    expect(notifier.shownJobs, isEmpty);
  });

  test('a few get one notification each, many are folded into one', () async {
    await check();
    server.jobs.addAll([
      job(200, 'cloudsync.sync'),
      job(201, 'cloudsync.sync', state: 'FAILED'),
    ]);
    await check();
    expect(notifier.shownJobs, ['Home: job 201 failed', 'Home: job 200 done']);

    notifier.shownJobs.clear();
    server.jobs.addAll([
      for (var i = 0; i < 4; i++) job(210 + i, 'rsynctask.run'),
    ]);
    await check();
    expect(notifier.shownJobs, hasLength(1));
    expect(notifier.shownJobs.single.split(', '), hasLength(4));
  });

  test('a notification that cannot be shown is retried', () async {
    await check();
    server.jobs.add(job(200, 'pool.scrub.run', arguments: ['tank']));
    final failing = AlertWatcher(store: store, notifier: _FailingNotifier());
    await failing.check([home()], minimum: AlertSeverity.critical);
    await check();
    expect(notifier.shownJobs, ['Home: job 200 done']);
  });

  test('alerts still come through when a job notification fails', () async {
    await check();
    server.alerts.add(alertJson('a3'));
    server.jobs.add(job(200, 'pool.scrub.run', arguments: ['tank']));
    final failing = _FailingNotifier();
    await AlertWatcher(
      store: store,
      notifier: failing,
    ).check([home()], minimum: AlertSeverity.critical);
    expect(failing.shown, ['Home: a3']);
    // The alert is recorded; the job is still to be told.
    await check();
    expect(notifier.shown, isEmpty);
    expect(notifier.shownJobs, ['Home: job 200 done']);
  });

  group('background check', () {
    Future<void> run(AppSettings settings) async {
      await SettingsRepository(store).save(settings);
      await runBackgroundAlertCheck(store: store, notifier: notifier);
    }

    test('announces finished jobs by default', () async {
      await InstanceRepository(store).save([home()]);
      const settings = AppSettings(alertNotifications: true);
      await run(settings);
      server.jobs.add(job(200, 'pool.scrub.run', arguments: ['tank']));
      await run(settings);
      expect(notifier.shownJobs, ['Home: job 200 done']);
    });

    test('keeps quiet when the setting is off', () async {
      await InstanceRepository(store).save([home()]);
      const settings = AppSettings(
        alertNotifications: true,
        jobNotifications: false,
      );
      await run(settings);
      server.jobs.add(job(200, 'pool.scrub.run', arguments: ['tank']));
      await run(settings);
      expect(notifier.shownJobs, isEmpty);
    });
  });

  test('the setting is on unless saved otherwise', () {
    expect(AppSettings.fromJson(const {}).jobNotifications, isTrue);
    expect(
      AppSettings.fromJson(const {'jobNotifications': false}).jobNotifications,
      isFalse,
    );
    expect(
      AppSettings.fromJson(const AppSettings(jobNotifications: false).toJson())
          .jobNotifications,
      isFalse,
    );
  });
}

class _FailingNotifier extends FakeAlertNotifier {
  @override
  Future<void> showJobs(server, jobs) => throw StateError('no permission');
}
