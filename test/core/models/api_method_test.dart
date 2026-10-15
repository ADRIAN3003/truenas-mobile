import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/models/api_method.dart';

void main() {
  test('parameters get a form kind from their schema', () {
    final method = ApiMethod.fromJson('x.update', {
      'job': false,
      'accepts': [
        {'type': 'integer', '_name_': 'id', '_required_': true},
        {
          '_name_': 'comment',
          'anyOf': [
            {'type': 'string'},
            {'type': 'null'},
          ],
          'default': null,
        },
        {
          '_name_': 'mode',
          'anyOf': [
            {'const': 'A'},
            {'const': 'B'},
          ],
        },
        {'type': 'boolean', '_name_': 'force', 'default': false},
        {'type': 'object', '_name_': 'data', 'properties': {}},
        {
          'enum': ['X', 'Y', null],
          '_name_': 'level',
        },
      ],
    });
    final kinds = method.params.map((p) => p.kind).toList();
    expect(kinds, [
      ParamKind.integer,
      ParamKind.string,
      ParamKind.choice,
      ParamKind.boolean,
      ParamKind.json,
      ParamKind.choice,
    ]);
    expect(method.params[0].required, isTrue);
    expect(method.params[1].nullable, isTrue);
    expect(method.params[1].hasDefault, isTrue);
    expect(method.params[2].choices, ['A', 'B']);
    expect(method.params[5].choices, ['X', 'Y']);
  });

  test('examples fill required properties and use defaults', () {
    final example = exampleFor({
      'type': 'object',
      'required': ['name'],
      'properties': {
        'name': {'type': 'string'},
        'size': {'type': 'integer', 'default': 10},
        'comment': {'type': 'string'},
        'tags': {'type': 'array', '_required_': true},
      },
    });
    expect(example, {'name': '', 'tags': <Object?>[]});
    expect(exampleFor({'type': 'integer', 'default': 5}), 5);
    expect(
      exampleFor({
        'anyOf': [
          {'type': 'string'},
          {'type': 'null'},
        ],
      }),
      isNull,
    );
  });

  test('read-only detection', () {
    ApiMethod m(String name, {bool job = false, bool filterable = false}) =>
        ApiMethod.fromJson(name, {'job': job, 'filterable': filterable});
    expect(m('pool.query', filterable: true).readOnly, isTrue);
    expect(m('system.info').readOnly, isTrue);
    expect(m('smb.config').readOnly, isTrue);
    expect(m('pool.dataset.compression_choices').readOnly, isTrue);
    expect(m('user.update').readOnly, isFalse);
    expect(m('pool.scrub.run', job: true).readOnly, isFalse);
    expect(m('pool.dataset.query').service, 'pool.dataset');
    expect(m('pool.dataset.query').shortName, 'query');
  });
}
