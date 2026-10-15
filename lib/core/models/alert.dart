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
