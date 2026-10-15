import 'json.dart';

/// One method from `core.get_methods`, with its documentation and the
/// JSON schemas of its positional parameters and result.
class ApiMethod {
  const ApiMethod({
    required this.name,
    required this.description,
    required this.job,
    required this.filterable,
    required this.downloadable,
    required this.uploadable,
    required this.noAuthRequired,
    required this.roles,
    required this.params,
    this.returns,
  });

  factory ApiMethod.fromJson(String name, Map<String, dynamic> json) {
    final accepts = json['accepts'];
    final returns = json['returns'];
    return ApiMethod(
      name: name,
      description: ((json['description'] ?? '') as Object).toString().trim(),
      job: json['job'] == true,
      filterable: json['filterable'] == true,
      downloadable: json['downloadable'] == true,
      uploadable: json['uploadable'] == true,
      noAuthRequired: json['no_auth_required'] == true,
      roles: [
        for (final r in json['roles'] as List<dynamic>? ?? const [])
          r.toString(),
      ],
      params: [
        if (accepts is List)
          for (final (i, schema) in accepts.indexed)
            ApiParam.fromSchema(asMap(schema), i),
      ],
      returns: returns is List && returns.isNotEmpty
          ? asMap(returns.first)
          : null,
    );
  }

  /// Full name, e.g. `pool.dataset.query`.
  final String name;
  final String description;

  /// Returns a job id instead of the result.
  final bool job;

  /// Takes `query-filters` and `query-options`.
  final bool filterable;

  /// Jobs that stream a file to or from the client.
  final bool downloadable;
  final bool uploadable;
  final bool noAuthRequired;
  final List<String> roles;
  final List<ApiParam> params;
  final Map<String, dynamic>? returns;

  /// `pool.dataset` for `pool.dataset.query`.
  String get service => name.substring(0, name.lastIndexOf('.'));

  /// `query` for `pool.dataset.query`.
  String get shortName => name.substring(name.lastIndexOf('.') + 1);

  /// First paragraph of the description, on one line.
  String get summary =>
      description.split('\n\n').first.replaceAll('\n', ' ').trim();

  /// Whether calling this is unlikely to change anything on the server.
  /// Used to skip the confirmation before running it.
  bool get readOnly {
    if (job) return false;
    final verb = shortName;
    return filterable ||
        const {
          'config',
          'get_instance',
          'summary',
          'status',
          'info',
          'choices',
        }.contains(verb) ||
        verb.startsWith('get_') ||
        verb.endsWith('_choices');
  }
}

/// The kind of input a parameter needs in a generated form.
enum ParamKind { string, integer, number, boolean, choice, json }

/// One positional parameter of an [ApiMethod].
class ApiParam {
  const ApiParam({
    required this.index,
    required this.name,
    required this.kind,
    required this.required,
    required this.nullable,
    required this.schema,
    this.description,
    this.choices = const [],
    this.defaultValue,
    this.hasDefault = false,
  });

  factory ApiParam.fromSchema(Map<String, dynamic> schema, int index) {
    final types = schemaTypes(schema);
    final nullable = types.remove('null');
    final enumValues = _enumOf(schema);
    final ParamKind kind;
    if (enumValues.isNotEmpty) {
      kind = ParamKind.choice;
    } else if (types.length == 1) {
      kind = switch (types.single) {
        'string' => ParamKind.string,
        'integer' => ParamKind.integer,
        'number' => ParamKind.number,
        'boolean' => ParamKind.boolean,
        _ => ParamKind.json,
      };
    } else {
      kind = ParamKind.json;
    }
    final name = (schema['_name_'] ?? schema['title'] ?? 'arg$index')
        .toString();
    final description = schema['description'] as String?;
    return ApiParam(
      index: index,
      name: name,
      kind: kind,
      required: schema['_required_'] == true,
      nullable: nullable,
      schema: schema,
      description: description == null || description.trim().isEmpty
          ? null
          : description.trim(),
      choices: enumValues,
      defaultValue: schema['default'],
      hasDefault: schema.containsKey('default'),
    );
  }

  final int index;
  final String name;
  final ParamKind kind;
  final bool required;
  final bool nullable;
  final Map<String, dynamic> schema;
  final String? description;
  final List<Object?> choices;
  final Object? defaultValue;
  final bool hasDefault;

  /// A starting value for the form: the default, or an example built from
  /// the schema.
  Object? get initialValue => hasDefault ? defaultValue : exampleFor(schema);
}

/// Every JSON type [schema] allows, looking through `anyOf` / `oneOf`.
Set<String> schemaTypes(Map<String, dynamic> schema) {
  final type = schema['type'];
  final types = <String>{
    if (type is String) type,
    if (type is List)
      for (final t in type) t.toString(),
  };
  for (final key in const ['anyOf', 'oneOf']) {
    for (final option in schema[key] as List<dynamic>? ?? const []) {
      types.addAll(schemaTypes(asMap(option)));
    }
  }
  if (types.isEmpty && schema['properties'] is Map) types.add('object');
  if (types.isEmpty && schema.containsKey('const')) {
    final value = schema['const'];
    types.add(switch (value) {
      String() => 'string',
      int() => 'integer',
      num() => 'number',
      bool() => 'boolean',
      null => 'null',
      _ => 'object',
    });
  }
  return types;
}

/// Allowed values when [schema] is an enum (or a union of constants).
List<Object?> _enumOf(Map<String, dynamic> schema) {
  final values = schema['enum'];
  if (values is List) return values.where((v) => v != null).toList();
  final options = schema['anyOf'] ?? schema['oneOf'];
  if (options is List && options.isNotEmpty) {
    final consts = <Object?>[];
    for (final option in options) {
      final o = asMap(option);
      if (o['type'] == 'null') continue;
      if (o.containsKey('const')) {
        consts.add(o['const']);
      } else if (o['enum'] is List) {
        consts.addAll((o['enum'] as List).where((v) => v != null));
      } else {
        return const [];
      }
    }
    return consts;
  }
  return const [];
}

/// A small example value for [schema]: defaults where given, required
/// object properties filled in, empty lists, and null for nullable values.
Object? exampleFor(Map<String, dynamic> schema, [int depth = 0]) {
  if (schema.containsKey('default')) return schema['default'];
  if (schema.containsKey('const')) return schema['const'];
  final enumValues = _enumOf(schema);
  if (enumValues.isNotEmpty) return enumValues.first;
  final types = schemaTypes(schema);
  if (types.contains('null')) return null;
  if (depth > 4) return null;
  if (types.contains('object')) {
    final properties = asMap(schema['properties']);
    final required = {
      for (final r in schema['required'] as List<dynamic>? ?? const [])
        r.toString(),
    };
    return {
      for (final MapEntry(:key, :value) in properties.entries)
        if (required.contains(key) || asMap(value)['_required_'] == true)
          key: exampleFor(asMap(value), depth + 1),
    };
  }
  if (types.contains('array')) return <Object?>[];
  if (types.contains('string')) return '';
  if (types.contains('integer') || types.contains('number')) return 0;
  if (types.contains('boolean')) return false;
  // Pydantic unions without a plain type: take the first option.
  final options = schema['anyOf'] ?? schema['oneOf'];
  if (options is List && options.isNotEmpty) {
    return exampleFor(asMap(options.first), depth + 1);
  }
  return null;
}
