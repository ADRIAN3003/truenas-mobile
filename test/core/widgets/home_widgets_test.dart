import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/models/alert.dart';
import 'package:truenas_mobile/core/models/pool_summary.dart';
import 'package:truenas_mobile/core/models/realtime_stats.dart';
import 'package:truenas_mobile/core/notifications/alert_watcher.dart';
import 'package:truenas_mobile/core/notifications/background_alerts.dart';
import 'package:truenas_mobile/core/settings/app_settings.dart';
import 'package:truenas_mobile/core/widgets/home_widget_data.dart';
import 'package:truenas_mobile/core/widgets/home_widget_sync.dart';
import 'package:truenas_mobile/core/widgets/home_widgets.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/alert_fakes.dart';
import '../../support/fake_truenas_server.dart';
import '../../support/home_widget_fakes.dart';
import '../../support/memory_store.dart';

ServerInstance serverAt(String id, String name, {String? url}) =>
    ServerInstance(
      id: id,
      name: name,
      url: url ?? 'http://127.0.0.1:1',
      authMethod: AuthMethod.password,
      username: 'truenas_admin',
      secret: 'secret',
    );

void main() {
  final l10n = localizationsFor(const Locale('en'));
  final now = DateTime.utc(2026, 10, 21, 8);

  Map<String, dynamic> data({
    List<PoolSummary> pools = const [],
    List<TrueNasAlert> alerts = const [],
    RealtimeStats? stats,
    AppLocalizations? strings,
  }) => serverWidgetData(
    server: serverAt('1', 'Home'),
    now: now,
    pools: pools,
    alerts: alerts,
    stats: stats,
    l10n: strings ?? l10n,
  );

  PoolSummary pool(
    String name, {
    String status = 'ONLINE',
    bool healthy = true,
    int allocated = 100,
  }) => PoolSummary(
    name: name,
    status: status,
    healthy: healthy,
    size: 1000,
    allocated: allocated,
  );

  TrueNasAlert alert(
    String id,
    AlertLevel level, {
    String text = 'Something',
    bool dismissed = false,
  }) => TrueNasAlert(
    id: id,
    level: level,
    message: text,
    klass: 'Test',
    dismissed: dismissed,
  );

  group('what a widget shows', () {
    test('healthy pools are green with their usage', () {
      final pools = data(pools: [pool('tank', allocated: 420)])['pools'];
      expect(pools['level'], 'ok');
      expect(pools['summary'], 'All pools healthy');
      expect(pools['items'], [
        {'name': 'tank', 'status': 'ONLINE', 'used': 42.0, 'level': 'ok'},
      ]);
    });

    test('a degraded pool is orange, a faulted one red', () {
      final degraded = data(pools: [pool('a', status: 'DEGRADED')])['pools'];
      expect(degraded['level'], 'warn');
      expect(degraded['summary'], '1 pool needs attention');
      final faulted = data(
        pools: [
          pool('a'),
          pool('b', status: 'FAULTED'),
          pool('c', status: 'OFFLINE'),
        ],
      )['pools'];
      expect(faulted['level'], 'bad');
      expect(faulted['summary'], '2 pools need attention');
    });

    test('a nearly full or unhealthy online pool is orange', () {
      expect(
        data(pools: [pool('a', allocated: 950)])['pools']['level'],
        'warn',
      );
      expect(
        data(pools: [pool('a', healthy: false)])['pools']['level'],
        'warn',
      );
    });

    test('no pools says so', () {
      expect(data()['pools']['summary'], 'No pools');
    });

    test('alerts: dismissed ones are left out, the worst come first', () {
      final alerts = data(
        alerts: [
          alert('1', AlertLevel.warning, text: 'Low space'),
          alert('2', AlertLevel.critical, text: 'Disk failed\nmore text'),
          alert('3', AlertLevel.info, dismissed: true),
          alert('4', AlertLevel.info, text: 'Update available'),
        ],
      )['alerts'];
      expect(alerts['level'], 'bad');
      expect(alerts['count'], 3);
      expect(alerts['summary'], '3 active alerts');
      expect((alerts['items'] as List).map((e) => e['text']), [
        'Disk failed',
        'Low space',
        'Update available',
      ]);
    });

    test('no active alerts is green; only warnings are orange', () {
      expect(data()['alerts']['summary'], 'No active alerts');
      expect(data()['alerts']['level'], 'ok');
      expect(
        data(alerts: [alert('1', AlertLevel.warning)])['alerts']['level'],
        'warn',
      );
    });

    test('long alert text is shortened', () {
      final text =
          data(
                alerts: [alert('1', AlertLevel.critical, text: 'x' * 300)],
              )['alerts']['items'][0]['text']
              as String;
      expect(text.length, lessThanOrEqualTo(110));
      expect(text, endsWith('…'));
    });

    test('CPU and memory come from one realtime sample', () {
      final system = data(
        stats: const RealtimeStats(
          cpuPercent: 23.46,
          cpuTemperature: 41.2,
          memoryTotal: 32 * 1024 * 1024 * 1024,
          memoryAvailable: 16 * 1024 * 1024 * 1024,
          arcSize: 0,
          receivedBytesPerSecond: 0,
          sentBytesPerSecond: 0,
        ),
      )['system'];
      expect(system['cpu'], 23.5);
      expect(system['memory'], 50.0);
      expect(system['memoryText'], '16.0 GiB of 32.0 GiB');
      expect(system['temperature'], '41 °C');
      expect(data().containsKey('system'), isFalse);
    });

    test('text is in the chosen language', () {
      final hu = data(
        strings: localizationsFor(const Locale('hu')),
        pools: [pool('a', status: 'DEGRADED')],
      );
      expect(hu['pools']['summary'], '1 tároló figyelmet igényel');
      expect(
        data(
          strings: localizationsFor(const Locale('hu')),
        )['alerts']['summary'],
        'Nincs aktív riasztás',
      );
    });
  });

  group('publishing', () {
    late FakeHomeWidgets bridge;
    late HomeWidgetPublisher publisher;

    setUp(() {
      bridge = FakeHomeWidgets();
      publisher = HomeWidgetPublisher(bridge);
    });

    Map<String, dynamic> entry(String id, {String name = 'Name'}) => {
      'id': id,
      'name': name,
      'updatedAt': 1,
      'unreachable': false,
    };

    test('saves the labels, the order and the default server', () async {
      final a = serverAt('a', 'A');
      final b = serverAt('b', 'B');
      await publisher.publish(
        servers: [a, b],
        fresh: {'b': entry('b')},
        labels: {'cpu': 'CPU'},
        chosenDefault: 'b',
      );
      expect(bridge.json['labels'], {'cpu': 'CPU'});
      expect(bridge.json['defaultId'], 'b');
      expect(bridge.servers.keys, ['a', 'b']);
      expect(bridge.servers['a'], {'id': 'a', 'name': 'A'});
      expect(bridge.reloads, 1);
    });

    test('keeps what it knew of servers it did not look at', () async {
      final a = serverAt('a', 'A');
      final b = serverAt('b', 'B');
      await publisher.publish(
        servers: [a, b],
        fresh: {'a': entry('a'), 'b': entry('b')},
        labels: const {},
      );
      await publisher.publish(
        servers: [a, b],
        fresh: {
          'a': {...entry('a'), 'updatedAt': 2},
        },
        labels: const {},
      );
      expect(bridge.servers['a']!['updatedAt'], 2);
      expect(bridge.servers['b']!['updatedAt'], 1);
    });

    test('an unreachable server keeps its old data, marked', () async {
      final a = serverAt('a', 'A');
      await publisher.publish(
        servers: [a],
        fresh: {'a': entry('a')},
        labels: const {},
      );
      await publisher.publish(
        servers: [a],
        fresh: const {},
        unreachable: {'a'},
        labels: const {},
      );
      expect(bridge.servers['a']!['updatedAt'], 1);
      expect(bridge.servers['a']!['unreachable'], true);
      // And a good look clears the mark.
      await publisher.publish(
        servers: [a],
        fresh: {'a': entry('a')},
        labels: const {},
      );
      expect(bridge.servers['a']!['unreachable'], false);
    });

    test('forgets servers that are no longer saved, and renames', () async {
      await publisher.publish(
        servers: [serverAt('a', 'A'), serverAt('b', 'B')],
        fresh: {'a': entry('a'), 'b': entry('b')},
        labels: const {},
      );
      await publisher.publish(
        servers: [serverAt('b', 'Renamed')],
        fresh: const {},
        labels: const {},
      );
      expect(bridge.servers.keys, ['b']);
      expect(bridge.servers['b']!['name'], 'Renamed');
      expect(bridge.json['defaultId'], 'b');
    });

    test('damaged saved data is replaced, not a crash', () async {
      bridge.document = '{not json';
      await publisher.publish(
        servers: [serverAt('a', 'A')],
        fresh: {'a': entry('a')},
        labels: const {},
      );
      expect(bridge.servers.keys, ['a']);
    });

    test(
      'the iOS widgets get what they need to sign in by themselves',
      () async {
        final a = serverAt('a', 'A', url: 'https://nas.example.com').copyWith(
          pinnedFingerprint: () => 'AB:CD',
          lastApiVersion: 'v25.04.2',
        );
        await publisher.publish(
          servers: [a],
          fresh: const {},
          labels: const {},
        );
        final saved = jsonDecode(bridge.credentials!) as Map<String, dynamic>;
        expect(saved['servers'], [
          {
            'id': 'a',
            'name': 'A',
            'url': 'https://nas.example.com',
            'authMethod': 'password',
            'username': 'truenas_admin',
            'secret': 'secret',
            'pinnedFingerprint': 'AB:CD',
            'apiVersion': 'v25.04.2',
          },
        ]);
        // The shared preferences never hold the secret.
        expect(bridge.document, isNot(contains('secret')));
      },
    );

    test('no servers, or clearing, takes the sign-in details away', () async {
      await publisher.publish(
        servers: [serverAt('a', 'A')],
        fresh: const {},
        labels: const {},
      );
      expect(bridge.credentials, isNotNull);
      await publisher.publish(servers: const [], fresh: const {}, labels: {});
      expect(bridge.credentials, isNull);
      await publisher.publish(
        servers: [serverAt('a', 'A')],
        fresh: const {},
        labels: const {},
      );
      await publisher.clear();
      expect(bridge.credentials, isNull);
    });
  });

  group('the words a widget works out itself', () {
    test('plurals come as templates, with the count left open', () {
      final en = homeWidgetLabels(l10n);
      expect(en['poolsAttentionOne'], '1 pool needs attention');
      expect(en['poolsAttentionMany'], '{count} pools need attention');
      expect(en['alertsCountOne'], '1 active alert');
      expect(en['alertsCountMany'], '{count} active alerts');
      expect(en['memoryText'], '{used} of {total}');
      expect(en['poolsOk'], 'All pools healthy');
      final hu = homeWidgetLabels(localizationsFor(const Locale('hu')));
      expect(hu['alertsCountMany'], '{count} aktív riasztás');
    });
  });

  group('a look at a server', () {
    late FakeTrueNasServer server;
    late FakeHomeWidgets bridge;
    late MemoryStore store;

    setUp(() async {
      server = await FakeTrueNasServer.start();
      bridge = FakeHomeWidgets();
      store = MemoryStore();
    });
    tearDown(() => server.close());

    ServerInstance home({String? url}) =>
        serverAt('1', 'Home', url: url ?? 'http://127.0.0.1:${server.port}');

    HomeWidgetCollector collector() => HomeWidgetCollector(
      publisher: HomeWidgetPublisher(bridge),
      locale: () => const Locale('en'),
      now: () => now,
    );

    test('the alert check also saves pools, CPU, memory and alerts', () async {
      await AlertWatcher(
        store: store,
        notifier: FakeAlertNotifier(),
      ).check([home()], minimum: AlertSeverity.critical, widgets: collector());
      final saved = bridge.servers['1']!;
      expect(saved['name'], 'Home');
      expect(saved['updatedAt'], now.millisecondsSinceEpoch);
      expect(saved['unreachable'], false);
      expect(saved['pools']['items'][0]['name'], 'tank');
      expect(saved['pools']['level'], 'ok');
      expect(saved['system']['cpu'], 23.5);
      expect(saved['system']['memory'], 37.5);
      expect(saved['alerts']['count'], 1);
      expect(saved['alerts']['level'], 'bad');
      expect(bridge.json['labels']['cpu'], 'CPU');
      expect(bridge.reloads, 1);
    });

    test('a server that cannot be reached keeps its last data', () async {
      final watcher = AlertWatcher(store: store, notifier: FakeAlertNotifier());
      await watcher.check(
        [home()],
        minimum: AlertSeverity.critical,
        widgets: collector(),
      );
      await watcher.check(
        [home(url: 'http://127.0.0.1:1')],
        minimum: AlertSeverity.critical,
        widgets: collector(),
      );
      final saved = bridge.servers['1']!;
      expect(saved['unreachable'], true);
      expect(saved['pools']['items'][0]['name'], 'tank');
    });

    test('without widgets nothing is saved', () async {
      await AlertWatcher(
        store: store,
        notifier: FakeAlertNotifier(),
      ).check([home()], minimum: AlertSeverity.critical);
      expect(bridge.document, isNull);
    });
  });

  group('the background check', () {
    late FakeTrueNasServer server;
    late FakeHomeWidgets bridge;
    late MemoryStore store;
    late FakeAlertNotifier notifier;

    setUp(() async {
      server = await FakeTrueNasServer.start();
      bridge = FakeHomeWidgets();
      store = MemoryStore();
      notifier = FakeAlertNotifier();
      await InstanceRepository(
        store,
      ).save([serverAt('1', 'Home', url: 'http://127.0.0.1:${server.port}')]);
    });
    tearDown(() => server.close());

    test('feeds the widgets even with alert notifications off', () async {
      await runBackgroundAlertCheck(
        store: store,
        notifier: notifier,
        widgets: bridge,
      );
      expect(bridge.servers.keys, ['1']);
      server.alerts.add(alertJson('new'));
      await runBackgroundAlertCheck(
        store: store,
        notifier: notifier,
        widgets: bridge,
      );
      expect(notifier.shown, isEmpty);
    });

    test('does nothing with no widget on a home screen', () async {
      bridge.installed = false;
      await runBackgroundAlertCheck(
        store: store,
        notifier: notifier,
        widgets: bridge,
      );
      expect(bridge.document, isNull);
      expect(store.values.containsKey('alertwatch.v1'), isFalse);
    });

    test('does nothing when widgets are switched off in settings', () async {
      await SettingsRepository(store)
          .save(const AppSettings(homeWidgets: false));
      await runBackgroundAlertCheck(
        store: store,
        notifier: notifier,
        widgets: bridge,
      );
      expect(bridge.document, isNull);
    });

    test('still tells about alerts, and feeds the widgets too', () async {
      await SettingsRepository(store)
          .save(const AppSettings(alertNotifications: true));
      await runBackgroundAlertCheck(
        store: store,
        notifier: notifier,
        widgets: bridge,
      );
      server.alerts.add(alertJson('a3'));
      await runBackgroundAlertCheck(
        store: store,
        notifier: notifier,
        widgets: bridge,
      );
      expect(notifier.shown, ['Home: a3']);
      expect(bridge.servers['1']!['alerts']['count'], 2);
    });
  });

  group('scheduling', () {
    late FakeBackgroundScheduler scheduler;
    late FakeHomeWidgets bridge;
    late AlertNotificationService service;

    setUp(() {
      scheduler = FakeBackgroundScheduler();
      bridge = FakeHomeWidgets();
      service = AlertNotificationService(
        scheduler: scheduler,
        notifier: FakeAlertNotifier(),
        store: MemoryStore(),
        widgets: bridge,
      );
    });

    test('a widget on the home screen is reason enough', () async {
      await service.resume(const AppSettings());
      expect(scheduler.scheduleCalls, 1);
    });

    test('no widget and no alerts: nothing to schedule', () async {
      bridge.installed = false;
      await service.resume(const AppSettings());
      expect(scheduler.scheduleCalls, 0);
    });

    test('widgets switched off in settings: nothing to schedule', () async {
      await service.resume(const AppSettings(homeWidgets: false));
      expect(scheduler.scheduleCalls, 0);
    });

    test('turning alerts off keeps the schedule for the widgets', () async {
      await service.resume(const AppSettings());
      await service.turnOff(keepForWidgets: true);
      expect(scheduler.scheduled, isTrue);
      await service.turnOff();
      expect(scheduler.scheduled, isFalse);
    });
  });
}
