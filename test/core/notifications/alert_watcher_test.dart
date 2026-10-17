import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/models/alert.dart';
import 'package:truenas_mobile/core/notifications/alert_watcher.dart';
import 'package:truenas_mobile/core/notifications/background_alerts.dart';
import 'package:truenas_mobile/core/settings/app_settings.dart';

import '../../support/alert_fakes.dart';
import '../../support/fake_truenas_server.dart';
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

  ServerInstance home({String id = '1', String? url}) => ServerInstance(
    id: id,
    name: 'Home',
    url: url ?? 'http://127.0.0.1:${server.port}',
    authMethod: AuthMethod.password,
    username: 'truenas_admin',
    secret: 'secret',
  );

  Future<void> check(
    List<ServerInstance> servers, {
    AlertSeverity minimum = AlertSeverity.critical,
    bool notify = true,
  }) => watcher.check(servers, minimum: minimum, notify: notify);

  test('the first look at a server only records what is there', () async {
    await check([home()]);
    expect(notifier.shown, isEmpty);
  });

  test('tells about a new critical alert once', () async {
    await check([home()]);
    server.alerts.add(alertJson('a3', text: 'Disk failed'));
    await check([home()]);
    expect(notifier.shown, ['Home: a3']);
    await check([home()]);
    expect(notifier.shown, hasLength(1));
  });

  test('ignores alerts below the chosen level and dismissed ones', () async {
    await check([home()]);
    server.alerts
      ..add(alertJson('w1', level: 'WARNING'))
      ..add(alertJson('i1', level: 'INFO'))
      ..add(alertJson('d1', dismissed: true));
    await check([home()]);
    expect(notifier.shown, isEmpty);

    // Lowering the level later does not bring the old ones back...
    await check([home()], minimum: AlertSeverity.warning);
    expect(notifier.shown, isEmpty);
    // ...but a new warning is news.
    server.alerts.add(alertJson('w2', level: 'WARNING'));
    await check([home()], minimum: AlertSeverity.warning);
    expect(notifier.shown, ['Home: w2']);
  });

  test('error, alert and emergency count as critical', () async {
    await check([home()]);
    server.alerts.addAll([
      alertJson('e1', level: 'ERROR'),
      alertJson('e2', level: 'EMERGENCY'),
    ]);
    await check([home()]);
    expect(notifier.shown, unorderedEquals(['Home: e1', 'Home: e2']));
  });

  test('one notification each for a few, one for many; worst first', () async {
    await check([home()]);
    server.alerts.addAll([
      alertJson('c1', level: 'CRITICAL'),
      alertJson('m1', level: 'EMERGENCY'),
    ]);
    await check([home()]);
    expect(notifier.shown, ['Home: m1', 'Home: c1']);

    notifier.shown.clear();
    server.alerts.addAll([for (var i = 0; i < 4; i++) alertJson('n$i')]);
    await check([home()]);
    expect(notifier.shown, hasLength(1));
    expect(notifier.shown.single.split(','), hasLength(4));
  });

  test('an alert that went away and came back is news again', () async {
    await check([home()]);
    server.alerts.add(alertJson('a3'));
    await check([home()]);
    server.alerts.removeLast();
    await check([home()]);
    server.alerts.add(alertJson('a3'));
    await check([home()]);
    expect(notifier.shown, hasLength(2));
  });

  test('recording only (turning it on) stays quiet', () async {
    server.alerts.add(alertJson('a3'));
    await check([home()], notify: false);
    expect(notifier.shown, isEmpty);
    // What was recorded is not news later either.
    await check([home()]);
    expect(notifier.shown, isEmpty);
  });

  test('an unreachable server is skipped and remembered', () async {
    await check([home()]);
    final dead = home(url: 'http://127.0.0.1:1');
    server.alerts.add(alertJson('a3'));
    await check([dead]);
    expect(notifier.shown, isEmpty);
    // Its record survived, so the alert is still reported once it is back.
    await check([home()]);
    expect(notifier.shown, ['Home: a3']);
  });

  test('a server that fails to sign in is skipped', () async {
    await check([home()]);
    server.alerts.add(alertJson('a3'));
    server.password = 'changed';
    await check([home()]);
    expect(notifier.shown, isEmpty);
    server.password = 'secret';
    await check([home()]);
    expect(notifier.shown, hasLength(1));
  });

  test('a notification that cannot be shown is retried', () async {
    await check([home()]);
    server.alerts.add(alertJson('a3'));
    final failing = AlertWatcher(store: store, notifier: _FailingNotifier());
    await failing.check([home()], minimum: AlertSeverity.critical);
    await check([home()]);
    expect(notifier.shown, hasLength(1));
  });

  test('keeps servers apart and forgets removed ones', () async {
    await check([home(id: '1'), home(id: '2')]);
    server.alerts.add(alertJson('a3'));
    await check([home(id: '1'), home(id: '2')]);
    expect(notifier.shown, hasLength(2));
    await check([home(id: '1')]);
    expect(
      (jsonDecode(store.values['alertwatch.v1']!) as Map).keys,
      contains('1'),
    );
    expect(
      (jsonDecode(store.values['alertwatch.v1']!) as Map).keys,
      isNot(contains('2')),
    );
  });

  group('background check', () {
    test('does nothing while the setting is off', () async {
      await InstanceRepository(store).save([home()]);
      await runBackgroundAlertCheck(store: store, notifier: notifier);
      expect(store.values.containsKey('alertwatch.v1'), isFalse);
    });

    test('reads the settings and servers from storage', () async {
      await InstanceRepository(store).save([home()]);
      await SettingsRepository(store)
          .save(const AppSettings(alertNotifications: true));
      await runBackgroundAlertCheck(store: store, notifier: notifier);
      server.alerts.add(alertJson('a3'));
      await runBackgroundAlertCheck(store: store, notifier: notifier);
      expect(notifier.shown, ['Home: a3']);
    });
  });

  group('turning it on', () {
    late FakeBackgroundScheduler scheduler;
    late AlertNotificationService service;

    setUp(() {
      scheduler = FakeBackgroundScheduler();
      service = AlertNotificationService(
        scheduler: scheduler,
        notifier: notifier,
        store: store,
      );
    });

    test('schedules the check and records the alerts already there', () async {
      server.alerts.add(alertJson('a3'));
      expect(
        await service.turnOn([home()], level: AlertSeverity.critical),
        isTrue,
      );
      expect(scheduler.scheduled, isTrue);
      expect(notifier.shown, isEmpty);
      await check([home()]);
      expect(notifier.shown, isEmpty);
    });

    test('does nothing when notifications are not allowed', () async {
      notifier.allowed = false;
      expect(
        await service.turnOn([home()], level: AlertSeverity.critical),
        isFalse,
      );
      expect(scheduler.scheduled, isFalse);
    });

    test('turning it off cancels the check', () async {
      await service.turnOn([home()], level: AlertSeverity.critical);
      await service.turnOff();
      expect(scheduler.scheduled, isFalse);
    });

    test('at start it is scheduled again only when it is on', () async {
      await service.resume(const AppSettings());
      expect(scheduler.scheduleCalls, 0);
      await service.resume(const AppSettings(alertNotifications: true));
      expect(scheduler.scheduleCalls, 1);
    });
  });
}

class _FailingNotifier extends FakeAlertNotifier {
  @override
  Future<void> show(ServerInstance server, List<TrueNasAlert> alerts) =>
      throw StateError('no permission');
}
