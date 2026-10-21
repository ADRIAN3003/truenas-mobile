import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/models/reporting.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';

import '../../support/fake_truenas_server.dart';

void main() {
  late FakeTrueNasServer server;
  late TrueNasSession session;

  Future<void> connect({bool legacy = false, bool reporting = true}) async {
    server = await FakeTrueNasServer.start();
    server
      ..legacy = legacy
      ..reporting = reporting;
    final (s, _) = await connectToInstance(
      ServerInstance(
        id: '1',
        name: 'Home',
        url: 'http://127.0.0.1:${server.port}',
        authMethod: AuthMethod.password,
        username: 'truenas_admin',
        secret: 'secret',
      ),
      confirmCertificate: (_) async => false,
      askOtp: () async => null,
    );
    session = s;
  }

  tearDown(() async {
    await session.close();
    await server.close();
  });

  List<dynamic> paramsOf(String method) =>
      server.calls.lastWhere((c) => c.$1 == method).$2;

  test('25.10 and newer use reporting.graphs and reporting.get_data', () async {
    await connect();
    expect(await session.reporting.isAvailable(), isTrue);
    final graphs = await session.reporting.graphs();
    expect(graphs.map((g) => g.name), [
      'cpu',
      'cputemp',
      'interface',
      'arcsize',
      'disktemp',
    ]);
    expect(graphs[2].identifiers, ['eno1', 'eno2']);
    expect(graphs[2].verticalLabel, 'Kilobits/s');

    final data = await session.reporting.data([
      (name: 'interface', identifier: 'eno1'),
      (name: 'cpu', identifier: null),
    ], ReportingRange.week);
    expect(data.map((d) => d.identifier), ['eno1', null]);
    expect(paramsOf('reporting.get_data'), [
      [
        {'name': 'interface', 'identifier': 'eno1'},
        {'name': 'cpu'},
      ],
      {'unit': 'WEEK'},
    ]);
  });

  test('25.04 uses the netdata names', () async {
    await connect(legacy: true);
    expect(await session.reporting.isAvailable(), isTrue);
    expect(await session.reporting.graphs(), hasLength(5));
    final data = await session.reporting.data([
      (name: 'cputemp', identifier: null),
    ], ReportingRange.hour);
    expect(data.single.legend, ['cpu0', 'cpu1']);
    expect(data.single.times, hasLength(5));
    expect(paramsOf('reporting.netdata_get_data').last, {'unit': 'HOUR'});
  });

  test('a server without reporting is not available', () async {
    await connect(reporting: false);
    expect(await session.reporting.isAvailable(), isFalse);
    expect(await session.reporting.graphs(), isEmpty);
    expect(
      await session.reporting.data([
        (name: 'cpu', identifier: null),
      ], ReportingRange.day),
      isEmpty,
    );
  });

  group('ReportingData', () {
    ReportingData parse(Map<String, dynamic> json) =>
        ReportingData.fromJson(json);

    test('reads rows as lists or maps, and times in seconds or ms', () {
      final data = parse({
        'name': 'cputemp',
        'legend': ['time', 'cpu0'],
        'data': [
          [1700000000, 40],
          {'time': 1700000060000, 'cpu0': 42},
          [1700000120, null],
          'junk',
        ],
      });
      expect(data.times, [
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
        DateTime.fromMillisecondsSinceEpoch(1700000060000),
        DateTime.fromMillisecondsSinceEpoch(1700000120000),
      ]);
      expect(data.column('cpu0'), [40, 42, null]);
      expect(data.mean(), [40, 42, null]);
    });

    test('cpu usage is everything but idle, and a short row is a gap', () {
      final data = parse({
        'name': 'cpu',
        'legend': ['time', 'user', 'system', 'idle'],
        'data': [
          [1, 10, 5, 85],
          [2, 60, 50, 0],
          [3],
        ],
      });
      expect(data.cpuUsage(), [15, 100, null]);
    });

    test('an empty answer is empty', () {
      expect(parse({'name': 'cpu'}).isEmpty, isTrue);
    });
  });

  test('units are worked out from the label', () {
    expect(bytesPerUnit('Kilobits/s', 0), 125);
    expect(bytesPerUnit('Megabits/s', 0), 125000);
    expect(bytesPerUnit('Mebibytes', 0), 1048576);
    expect(bytesPerUnit('Bytes', 0), 1);
    expect(bytesPerUnit('Celsius', 7), 7);
    expect(bytesPerUnit(null, 7), 7);
  });

  test('series statistics skip gaps', () {
    final stats = SeriesStats.of([2, null, 4, 9])!;
    expect(stats.average, 5);
    expect(stats.peak, 9);
    expect(SeriesStats.of([null]), isNull);
  });
}
