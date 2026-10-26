import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/models/app_catalog.dart';
import 'package:truenas_mobile/core/models/app_values.dart';

import '../../support/fake_truenas_server.dart';

Map<String, dynamic> _plex() => {
  'name': 'plex',
  'title': 'Plex',
  'train': 'stable',
  'latest_version': '2.0.1',
  'versions': {
    '1.9.0': {
      'version': '1.9.0',
      'human_version': '1.40.0_1.9.0',
      'schema': FakeTrueNasServer.plexSchema(),
    },
    '2.0.1': {
      'version': '2.0.1',
      'human_version': '1.41.0_2.0.1',
      'schema': FakeTrueNasServer.plexSchema(),
    },
  },
};

AppConfigSchema _schema() => CatalogAppDetails.fromJson(_plex()).latest!.schema;

void main() {
  group('catalog details', () {
    test('read the versions newest first, with the latest picked', () {
      final details = CatalogAppDetails.fromJson(_plex());
      expect(details.versions.map((v) => v.version), ['2.0.1', '1.9.0']);
      expect(details.latest!.version, '2.0.1');
      expect(details.version('1.9.0')!.humanVersion, '1.40.0_1.9.0');
      expect(details.app.title, 'Plex');
      expect(details.app.train, 'stable');
    });

    test('versions compare number by number', () {
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareVersions('2.0', '2.0.1'), lessThan(0));
      expect(compareVersions('1.2.3', '1.2.3'), 0);
    });

    test('a question reads its type, choices and rules', () {
      final network = _schema().questions.firstWhere(
        (q) => q.variable == 'network',
      );
      final port = network.schema.attrs.single;
      expect(network.schema.type, 'dict');
      expect(port.schema.type, 'int');
      expect(port.schema.min, 9000);
      expect(port.schema.required, isTrue);
      final zone = _schema().questions.firstWhere(
        (q) => q.variable == 'timezone',
      );
      expect(zone.schema.choices.map((c) => c.value), [
        'UTC',
        'Europe/Budapest',
      ]);
    });
  });

  group('values', () {
    test('start from every default, sub-questions and nested settings too', () {
      expect(AppValues.defaults(_schema().questions), {
        'claim_token': '',
        'timezone': 'UTC',
        'enable_logs': false,
        'log_level': 'info',
        'network': {'web_port': 32400},
        'extra_env': <Object?>[],
        'storage': {'type': 'ix_volume', 'host_path': ''},
      });
    });

    test('a sub-question shows only while its parent has the right answer', () {
      final questions = _schema().questions;
      List<String> shown(bool logs) => [
        for (final q in AppValues.applicable(questions, {'enable_logs': logs}))
          q.variable,
      ];
      expect(shown(false), isNot(contains('log_level')));
      expect(shown(true), contains('log_level'));
    });

    test('show_if looks at the sibling setting', () {
      final storage = _schema().questions
          .firstWhere((q) => q.variable == 'storage')
          .schema
          .attrs;
      List<String> shown(String type) => [
        for (final q in AppValues.applicable(storage, {'type': type}))
          q.variable,
      ];
      expect(shown('ix_volume'), ['type']);
      expect(shown('host_path'), ['type', 'host_path']);
    });

    test('pruning drops what does not apply and keeps what the schema '
        'does not know', () {
      final questions = _schema().questions;
      final values = AppValues.defaults(questions)
        ..['ix_volumes'] = {'data': 1}
        ..['storage'] = {'type': 'ix_volume', 'host_path': '/old'};
      final pruned = AppValues.prune(questions, values);
      expect(pruned.containsKey('log_level'), isFalse);
      expect(pruned['storage'], {'type': 'ix_volume'});
      expect(pruned['ix_volumes'], {'data': 1});
    });

    test('fill adds the settings a newer version brought', () {
      final filled = AppValues.fill(_schema().questions, {
        'network': <String, dynamic>{},
        'timezone': 'Europe/Budapest',
      });
      expect(filled['timezone'], 'Europe/Budapest');
      expect((filled['network'] as Map)['web_port'], 32400);
      expect(filled['claim_token'], '');
    });

    test('the first problem is found inside dicts and list entries', () {
      final questions = _schema().questions;
      final values = AppValues.defaults(questions);
      expect(AppValues.firstProblem(questions, values), isNull);

      (values['network'] as Map<String, dynamic>)['web_port'] = 80;
      final low = AppValues.firstProblem(questions, values)!;
      expect(low.$1.variable, 'web_port');
      expect(low.$2, AppValueProblem.tooSmall);

      (values['network'] as Map<String, dynamic>)['web_port'] = 32400;
      values['extra_env'] = [
        {'name': '', 'value': 'x'},
      ];
      final empty = AppValues.firstProblem(questions, values)!;
      expect(empty.$1.variable, 'name');
      expect(empty.$2, AppValueProblem.required);
    });

    test('a hidden-by-rule setting is not checked', () {
      final questions = _schema().questions;
      final values = AppValues.defaults(questions);
      // host_path is required but only when the type is host_path.
      expect(AppValues.firstProblem(questions, values), isNull);
      (values['storage'] as Map<String, dynamic>)['type'] = 'host_path';
      expect(
        AppValues.firstProblem(questions, values)!.$1.variable,
        'host_path',
      );
    });
  });
}
