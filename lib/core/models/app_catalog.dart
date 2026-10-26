import 'json.dart';

/// An app offered by the catalog, from `app.available`.
class CatalogApp {
  const CatalogApp({
    required this.name,
    required this.train,
    required this.title,
    required this.categories,
    required this.installed,
    required this.healthy,
    this.description,
    this.iconUrl,
    this.latestVersion,
    this.humanVersion,
    this.home,
    this.recommended = false,
  });

  factory CatalogApp.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString();
    return CatalogApp(
      name: name,
      train: (json['train'] ?? 'stable').toString(),
      title: (json['title'] as String?)?.trim().isNotEmpty ?? false
          ? (json['title'] as String).trim()
          : name,
      description: (json['description'] as String?)?.trim(),
      iconUrl: json['icon_url'] as String?,
      categories: [
        for (final c in json['categories'] as List<dynamic>? ?? const [])
          c.toString(),
      ],
      latestVersion: json['latest_version'] as String?,
      humanVersion:
          (json['latest_human_version'] ?? json['latest_app_version'])
              as String?,
      installed: json['installed'] == true,
      healthy: json['healthy'] != false,
      home: json['home'] as String?,
      recommended: json['recommended'] == true,
    );
  }

  /// The catalog name, e.g. `jellyfin`. An installed copy may be called
  /// something else.
  final String name;

  /// `stable`, `community`, `enterprise` or `test`.
  final String train;
  final String title;
  final String? description;
  final String? iconUrl;
  final List<String> categories;

  /// The newest chart version (`1.2.3`).
  final String? latestVersion;

  /// What the project's own version is called (`10.10.7_1.2.3`).
  final String? humanVersion;

  /// Whether an app made from it is already installed.
  final bool installed;
  final bool healthy;
  final String? home;
  final bool recommended;
}

/// A section of the install form.
class AppSchemaGroup {
  const AppSchemaGroup(this.name, this.description);

  final String name;
  final String? description;
}

/// One value an enumerated question accepts.
class AppChoice {
  const AppChoice(this.value, this.label);

  final Object? value;
  final String label;
}

/// One setting of an app, from the catalog's `questions`.
class AppQuestion {
  const AppQuestion({
    required this.variable,
    required this.label,
    required this.schema,
    this.group,
    this.description,
  });

  factory AppQuestion.fromJson(Map<String, dynamic> json) {
    final variable = (json['variable'] ?? '').toString();
    return AppQuestion(
      variable: variable,
      label: (json['label'] as String?)?.trim().isNotEmpty ?? false
          ? (json['label'] as String).trim()
          : variable,
      description: (json['description'] as String?)?.trim(),
      group: json['group'] as String?,
      schema: AppQuestionSchema.fromJson(asMap(json['schema'])),
    );
  }

  /// The key in the app's values.
  final String variable;
  final String label;
  final String? description;

  /// Which [AppSchemaGroup] shows it.
  final String? group;
  final AppQuestionSchema schema;

  /// Hidden settings keep their default and are never shown.
  bool get isHidden => schema.hidden;
}

/// How a setting's value looks.
class AppQuestionSchema {
  const AppQuestionSchema({
    required this.type,
    this.defaultValue,
    this.required = false,
    this.nullable = false,
    this.choices = const [],
    this.min,
    this.max,
    this.minLength,
    this.maxLength,
    this.secret = false,
    this.hidden = false,
    this.editable = true,
    this.showIf = const [],
    this.showSubquestionsIf,
    this.subquestions = const [],
    this.attrs = const [],
    this.items = const [],
    this.validChars,
    this.validCharsError,
    this.references = const [],
  });

  factory AppQuestionSchema.fromJson(Map<String, dynamic> json) {
    List<AppQuestion> questions(Object? value) => [
      for (final q in value as List<dynamic>? ?? const [])
        if (q is Map<String, dynamic>) AppQuestion.fromJson(q),
    ];

    return AppQuestionSchema(
      type: (json['type'] ?? 'string').toString(),
      defaultValue: json['default'],
      required: json['required'] == true,
      nullable: json['null'] == true,
      choices: [
        for (final e in json['enum'] as List<dynamic>? ?? const [])
          if (e is Map<String, dynamic>)
            AppChoice(e['value'], (e['description'] ?? e['value']).toString())
          else
            AppChoice(e, e.toString()),
      ],
      min: json['min'] as num?,
      max: json['max'] as num?,
      minLength: json['min_length'] as int?,
      maxLength: json['max_length'] as int?,
      secret: json['private'] == true,
      hidden: json['hidden'] == true,
      editable: json['editable'] != false && json['immutable'] != true,
      showIf: [
        for (final rule in json['show_if'] as List<dynamic>? ?? const [])
          if (rule is List && rule.length >= 3) rule,
      ],
      showSubquestionsIf: json['show_subquestions_if'],
      subquestions: questions(json['subquestions']),
      attrs: questions(json['attrs']),
      items: questions(json['items']),
      validChars: json['valid_chars'] as String?,
      validCharsError: json['valid_chars_error'] as String?,
      references: [
        for (final r in json['\$ref'] as List<dynamic>? ?? const [])
          r.toString(),
      ],
    );
  }

  /// `string`, `int`, `boolean`, `dict`, `list`, `path`, `hostpath`,
  /// `ipaddr`, `cron`, `text` and a few more.
  final String type;
  final Object? defaultValue;
  final bool required;

  /// Whether `null` is a valid value.
  final bool nullable;

  /// The only values allowed, when the setting is a pick from a list.
  final List<AppChoice> choices;
  final num? min;
  final num? max;
  final int? minLength;
  final int? maxLength;

  /// A password, token or other secret.
  final bool secret;
  final bool hidden;

  /// False for settings that cannot change after the app is installed.
  final bool editable;

  /// `[[sibling, '=', value], ...]`: shown only when all of them hold.
  final List<List<dynamic>> showIf;

  /// The value of this setting that shows [subquestions].
  final Object? showSubquestionsIf;
  final List<AppQuestion> subquestions;

  /// The fields of a `dict`.
  final List<AppQuestion> attrs;

  /// What a `list` holds (one entry, normally a `dict`).
  final List<AppQuestion> items;
  final String? validChars;
  final String? validCharsError;

  /// `$ref` entries such as `definitions/certificate`.
  final List<String> references;

  bool get isContainer => type == 'dict' || type == 'list';
}

/// The form of one version of an app: its sections and settings.
class AppConfigSchema {
  const AppConfigSchema({this.groups = const [], this.questions = const []});

  factory AppConfigSchema.fromJson(Map<String, dynamic> json) =>
      AppConfigSchema(
        groups: [
          for (final g in json['groups'] as List<dynamic>? ?? const [])
            if (g is Map<String, dynamic>)
              AppSchemaGroup(
                (g['name'] ?? '').toString(),
                g['description'] as String?,
              ),
        ],
        questions: [
          for (final q in json['questions'] as List<dynamic>? ?? const [])
            if (q is Map<String, dynamic>) AppQuestion.fromJson(q),
        ],
      );

  final List<AppSchemaGroup> groups;
  final List<AppQuestion> questions;
}

/// One installable version of a catalog app.
class CatalogVersion {
  const CatalogVersion({
    required this.version,
    required this.schema,
    this.humanVersion,
  });

  /// The chart version, e.g. `1.2.3`.
  final String version;
  final String? humanVersion;
  final AppConfigSchema schema;
}

/// A catalog app with its versions, from `catalog.get_app_details`.
class CatalogAppDetails {
  const CatalogAppDetails({
    required this.app,
    required this.versions,
    this.readme,
  });

  factory CatalogAppDetails.fromJson(Map<String, dynamic> json) {
    final versions = <CatalogVersion>[];
    for (final MapEntry(:key, :value) in asMap(json['versions']).entries) {
      final v = asMap(value);
      versions.add(
        CatalogVersion(
          version: (v['version'] ?? key).toString(),
          humanVersion: v['human_version'] as String?,
          schema: AppConfigSchema.fromJson(asMap(v['schema'])),
        ),
      );
    }
    versions.sort((a, b) => compareVersions(b.version, a.version));
    return CatalogAppDetails(
      app: CatalogApp.fromJson(json),
      versions: versions,
      readme: json['app_readme'] as String?,
    );
  }

  final CatalogApp app;

  /// Newest first.
  final List<CatalogVersion> versions;
  final String? readme;

  /// The version the catalog calls latest, else the highest one.
  CatalogVersion? get latest =>
      versions.where((v) => v.version == app.latestVersion).firstOrNull ??
      versions.firstOrNull;

  CatalogVersion? version(String? version) =>
      versions.where((v) => v.version == version).firstOrNull;
}

/// Orders dotted versions such as `1.10.2` numerically; text parts compare
/// as text.
int compareVersions(String a, String b) {
  final left = a.split(RegExp(r'[.\-_+]'));
  final right = b.split(RegExp(r'[.\-_+]'));
  for (var i = 0; i < left.length || i < right.length; i++) {
    if (i >= left.length) return -1;
    if (i >= right.length) return 1;
    final x = int.tryParse(left[i]);
    final y = int.tryParse(right[i]);
    final c = x != null && y != null
        ? x.compareTo(y)
        : left[i].compareTo(right[i]);
    if (c != 0) return c;
  }
  return 0;
}

/// Where Docker (and so every app) stands, from `docker.status`.
enum DockerState {
  running,
  unconfigured,
  starting,
  stopped,
  error,
  unknown;

  static DockerState parse(Object? value) =>
      switch (value?.toString().toUpperCase()) {
        'RUNNING' => running,
        'UNCONFIGURED' => unconfigured,
        'INITIALIZING' || 'STARTING' || 'PENDING' => starting,
        'STOPPED' => stopped,
        'FAILED' || 'ERROR' => error,
        _ => unknown,
      };

  /// Whether an app can be installed now.
  bool get canInstall => this == running || this == unknown;
}
