import 'json.dart';

enum JobState {
  waiting,
  running,
  success,
  failed,
  aborted;

  static JobState parse(Object? value) => JobState.values.firstWhere(
    (state) => state.name == value.toString().toLowerCase(),
    orElse: () => JobState.waiting,
  );

  bool get isActive => this == waiting || this == running;
}

/// A middleware job, from `core.get_jobs` or its events.
class TrueNasJob {
  const TrueNasJob({
    required this.id,
    required this.method,
    required this.state,
    required this.percent,
    required this.progressText,
    required this.abortable,
    this.description,
    this.error,
    this.started,
    this.finished,
    this.raw = const {},
  });

  factory TrueNasJob.fromJson(Map<String, dynamic> json) {
    final progress = asMap(json['progress']);
    final percent = progress['percent'];
    return TrueNasJob(
      id: asInt(json['id']),
      method: (json['method'] ?? '').toString(),
      state: JobState.parse(json['state']),
      percent: percent is num ? percent.toDouble() : null,
      progressText: (progress['description'] ?? '').toString(),
      abortable: json['abortable'] == true,
      description: json['description'] as String?,
      error: json['error'] as String?,
      started: asDate(json['time_started']),
      finished: asDate(json['time_finished']),
      raw: json,
    );
  }

  final int id;

  /// API method that started the job, e.g. `pool.scrub.run`.
  final String method;
  final JobState state;

  /// 0 to 100, or null when the job does not report progress.
  final double? percent;
  final String progressText;
  final bool abortable;
  final String? description;
  final String? error;
  final DateTime? started;
  final DateTime? finished;

  /// The job as the server sent it, kept so events can be merged into it.
  final Map<String, dynamic> raw;

  String get title => description?.isNotEmpty == true ? description! : method;

  /// Applies a `core.get_jobs` CHANGED event's `fields`.
  TrueNasJob merge(Map<String, dynamic> fields) =>
      TrueNasJob.fromJson({...raw, ...fields});
}
