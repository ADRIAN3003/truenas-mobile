import 'json.dart';

enum AlertLevel {
  info,
  notice,
  warning,
  error,
  critical,
  alert,
  emergency;

  static AlertLevel parse(Object? value) => AlertLevel.values.firstWhere(
    (level) => level.name == value.toString().toLowerCase(),
    orElse: () => AlertLevel.info,
  );

  /// Grouping used for colours and counts.
  AlertSeverity get severity => switch (this) {
    info || notice => AlertSeverity.info,
    warning => AlertSeverity.warning,
    error || critical || alert || emergency => AlertSeverity.critical,
  };
}

enum AlertSeverity { info, warning, critical }

/// An entry from `alert.list`.
class TrueNasAlert {
  const TrueNasAlert({
    required this.id,
    required this.level,
    required this.message,
    required this.klass,
    required this.dismissed,
    this.time,
  });

  factory TrueNasAlert.fromJson(Map<String, dynamic> json) => TrueNasAlert(
    id: json['uuid'].toString(),
    level: AlertLevel.parse(json['level']),
    message: (json['formatted'] ?? json['text'] ?? '').toString().trim(),
    klass: (json['klass'] ?? '').toString(),
    dismissed: json['dismissed'] == true,
    time: asDate(json['datetime']),
  );

  final String id;
  final AlertLevel level;

  /// Human-readable text (may contain simple HTML from the server).
  final String message;
  final String klass;
  final bool dismissed;
  final DateTime? time;

  /// [message] without HTML tags such as `<br>` or `<a>`.
  String get plainMessage => message
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .trim();
}

/// One kind of alert (TrueNAS calls it an alert class), e.g. `ScrubPaused`.
/// Its [id] is the `klass` of the alerts of that kind.
class AlertKind {
  const AlertKind(this.id, {this.title, this.category});

  factory AlertKind.fromJson(Map<String, dynamic> json) => AlertKind(
    json['id'].toString(),
    title: json['title'] as String?,
    category: json['category'] as String?,
  );

  /// The kinds in an `alert.list_categories` result: a list of categories,
  /// each with its `classes`. Anything unexpected is skipped.
  static List<AlertKind> fromCategories(Object? result) => [
    if (result is List)
      for (final category in result)
        if (category is Map)
          for (final klass in (category['classes'] as List?) ?? const [])
            if (klass is Map && klass['id'] != null)
              AlertKind(
                klass['id'].toString(),
                title: klass['title'] as String?,
                category: category['title'] as String?,
              ),
  ];

  final String id;

  /// The name TrueNAS shows, when it is known.
  final String? title;

  /// The group TrueNAS puts it in (Storage, Hardware, ...).
  final String? category;

  /// [title], or the id made readable (`PoolStatus` is "Pool Status").
  String get label => title ?? humanizeAlertKind(id);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
  };
}

/// `PoolStatus` as "Pool Status".
String humanizeAlertKind(String id) => id
    .replaceAllMapped(
      RegExp(r'(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])'),
      (_) => ' ',
    )
    .trim();
