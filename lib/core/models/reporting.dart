import 'json.dart';

/// How far back a history chart reaches. [unit] is what
/// `reporting.netdata_get_data` calls it.
enum ReportingRange {
  hour('HOUR'),
  day('DAY'),
  week('WEEK'),
  month('MONTH');

  const ReportingRange(this.unit);

  final String unit;
}

/// A kind of chart the server can draw: `cpu`, `interface`, `disktemp`...
/// [identifiers] lists what it can be asked about (interface or disk names).
class ReportingGraph {
  const ReportingGraph({
    required this.name,
    required this.title,
    required this.verticalLabel,
    required this.identifiers,
  });

  factory ReportingGraph.fromJson(Map<String, dynamic> json) {
    final identifiers = json['identifiers'];
    return ReportingGraph(
      name: (json['name'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      verticalLabel: (json['vertical_label'] ?? '').toString(),
      identifiers: identifiers is List
          ? [for (final i in identifiers) i.toString()]
          : const [],
    );
  }

  final String name;
  final String title;

  /// The unit of the values, as the server words it ("Kilobits/s").
  final String verticalLabel;
  final List<String> identifiers;
}

/// What to ask `reporting.netdata_get_data` for.
typedef ReportingRequest = ({String name, String? identifier});

/// The samples of one graph over time. A row is a time and one value per
/// [legend] entry; a missing value is null.
class ReportingData {
  const ReportingData({
    required this.name,
    required this.identifier,
    required this.legend,
    required this.times,
    required this.columns,
  });

  factory ReportingData.fromJson(Map<String, dynamic> json) {
    final legend = [
      for (final l in json['legend'] as List? ?? const []) l.toString(),
    ];
    // The first legend entry is the time column.
    final names = legend.isNotEmpty && legend.first == 'time'
        ? legend.skip(1).toList()
        : legend;
    final times = <DateTime>[];
    final columns = [for (final _ in names) <double?>[]];
    for (final row in json['data'] as List? ?? const []) {
      final List<Object?> cells;
      if (row is List) {
        cells = row.cast<Object?>();
      } else if (row is Map) {
        cells = [row['time'], for (final n in names) row[n]];
      } else {
        continue;
      }
      if (cells.isEmpty || cells.first is! num) continue;
      final seconds = (cells.first as num).toDouble();
      // Seconds since the epoch; some builds send milliseconds.
      times.add(
        DateTime.fromMillisecondsSinceEpoch(
          (seconds > 1e11 ? seconds : seconds * 1000).round(),
        ),
      );
      for (var i = 0; i < names.length; i++) {
        final cell = i + 1 < cells.length ? cells[i + 1] : null;
        columns[i].add(cell is num && cell.isFinite ? cell.toDouble() : null);
      }
    }
    return ReportingData(
      name: (json['name'] ?? '').toString(),
      identifier: json['identifier']?.toString(),
      legend: names,
      times: times,
      columns: columns,
    );
  }

  final String name;
  final String? identifier;

  /// The data columns' names, without the time.
  final List<String> legend;
  final List<DateTime> times;
  final List<List<double?>> columns;

  bool get isEmpty => times.isEmpty || columns.isEmpty;

  /// The column called [name], or null.
  List<double?>? column(String name) {
    final i = legend.indexOf(name);
    return i < 0 ? null : columns[i];
  }

  /// Per row, [combine] of the values that are there (null when none are).
  List<double?> combined(double Function(List<double> values) combine) => [
    for (var row = 0; row < times.length; row++)
      () {
        final values = [
          for (final c in columns)
            if (c[row] != null) c[row]!,
        ];
        return values.isEmpty ? null : combine(values);
      }(),
  ];

  /// CPU busy time, 0 to 100: everything the `cpu` graph lists but idle.
  List<double?> cpuUsage() {
    final busy = [
      for (var i = 0; i < legend.length; i++)
        if (legend[i] != 'idle') columns[i],
    ];
    return [
      for (var row = 0; row < times.length; row++)
        () {
          var sum = 0.0;
          var any = false;
          for (final c in busy) {
            final v = c[row];
            if (v != null) {
              sum += v.abs();
              any = true;
            }
          }
          return any ? sum.clamp(0.0, 100.0).toDouble() : null;
        }(),
    ];
  }

  /// The mean of all columns, e.g. the cores' temperatures.
  List<double?> mean() => combined((v) => v.reduce((a, b) => a + b) / v.length);
}

/// Multiplier that turns a value the server labelled [verticalLabel] into
/// bytes (or bytes per second), or [fallback] when the label is not
/// recognised. TrueNAS draws traffic in kilobits per second and memory in
/// mebibytes, and says so in the label.
double bytesPerUnit(String? verticalLabel, double fallback) {
  final label = (verticalLabel ?? '').toLowerCase();
  double prefix(Map<String, double> prefixes) {
    for (final entry in prefixes.entries) {
      if (label.contains(entry.key)) return entry.value;
    }
    return 1;
  }

  if (label.contains('bit')) {
    final bits = prefix({'kilo': 1e3, 'mega': 1e6, 'giga': 1e9, 'tera': 1e12});
    return bits / 8;
  }
  if (label.contains('byte')) {
    return prefix({
      'kibi': 1024,
      'mebi': 1048576,
      'gibi': 1073741824,
      'kilo': 1e3,
      'mega': 1e6,
      'giga': 1e9,
    });
  }
  return fallback;
}

/// Statistics of a series for the line under its chart.
class SeriesStats {
  const SeriesStats({required this.average, required this.peak});

  /// Null when there are no values.
  static SeriesStats? of(Iterable<double?> values) {
    var count = 0;
    var sum = 0.0;
    var peak = double.negativeInfinity;
    for (final v in values) {
      if (v == null) continue;
      count++;
      sum += v;
      if (v > peak) peak = v;
    }
    return count == 0 ? null : SeriesStats(average: sum / count, peak: peak);
  }

  final double average;
  final double peak;
}

/// Lists the graphs from `reporting.netdata_graphs` by name.
List<ReportingGraph> parseGraphs(Object? result) => [
  for (final g in result as List? ?? const [])
    ReportingGraph.fromJson(asMap(g)),
];
