import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/reporting.dart';

/// One line of a [HistoryChart]: [values] are the samples at [times], with
/// null where the server had none.
class ChartLine {
  const ChartLine(this.name, this.color, this.times, this.values);

  final String name;
  final Color color;
  final List<DateTime> times;
  final List<double?> values;
}

/// A line chart of what the server recorded over a [range], with a time axis,
/// a value axis and a touch tooltip.
class HistoryChart extends StatelessWidget {
  const HistoryChart({
    super.key,
    required this.lines,
    required this.range,
    required this.formatValue,
    this.maxY,
    this.zeroBased = true,
  });

  final List<ChartLine> lines;
  final ReportingRange range;
  final String Function(double) formatValue;

  /// A fixed top of the value axis (100 for a percentage).
  final double? maxY;

  /// Whether the value axis starts at zero; temperatures zoom in instead.
  final bool zeroBased;

  DateFormat _axisTime(String locale) => switch (range) {
    ReportingRange.hour || ReportingRange.day => DateFormat.Hm(locale),
    ReportingRange.week || ReportingRange.month => DateFormat.MMMd(locale),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final axisTime = _axisTime(locale);
    final tipTime = DateFormat.MMMd(locale).add_Hm();
    final times = lines.expand((l) => l.times);
    final start = times.reduce((a, b) => a.isBefore(b) ? a : b);
    final end = times.reduce((a, b) => a.isAfter(b) ? a : b);
    final span = math.max(end.difference(start).inSeconds, 1).toDouble();
    double x(DateTime t) => t.difference(start).inSeconds.toDouble();

    final values = [
      for (final l in lines)
        for (final v in l.values) ?v,
    ];
    final low = values.isEmpty ? 0.0 : values.reduce(math.min);
    final high = values.isEmpty ? 1.0 : values.reduce(math.max);
    final double bottom;
    final double top;
    final double? step;
    if (zeroBased) {
      bottom = 0;
      top = maxY ?? (high <= 0 ? 1 : high * 1.15);
      step = null;
    } else {
      // Round degrees: a step of 1, 2, 5, 10... and a range that is a
      // whole number of steps, so the axis labels line up with the grid.
      final wanted = math.max((high - low + 2) / 4, 1.0);
      step = [
        1.0,
        2.0,
        5.0,
        10.0,
        20.0,
        50.0,
      ].firstWhere((s) => s >= wanted, orElse: () => wanted.ceilToDouble());
      bottom = ((low - 1) / step).floorToDouble() * step;
      top = math.max(((high + 1) / step).ceilToDouble() * step, bottom + step);
    }

    final muted = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // The values are also written under the chart, so screen readers skip it.
    return ExcludeSemantics(
      child: SizedBox(
        height: 190,
        child: LineChart(
          duration: Duration.zero,
          LineChartData(
            minX: 0,
            maxX: span,
            minY: bottom,
            maxY: top,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 62,
                  interval: step,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(formatValue(value), style: muted),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  interval: span / 4,
                  minIncluded: false,
                  maxIncluded: false,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      axisTime.format(
                        start.add(Duration(seconds: value.round())),
                      ),
                      style: muted,
                    ),
                  ),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                getTooltipItems: (spots) => [
                  for (final (i, spot) in spots.indexed)
                    LineTooltipItem(
                      [
                        if (i == 0)
                          tipTime.format(
                            start.add(Duration(seconds: spot.x.round())),
                          ),
                        '${lines[spot.barIndex].name} ${formatValue(spot.y)}',
                      ].join('\n'),
                      TextStyle(color: theme.colorScheme.onInverseSurface),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              for (final l in lines)
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < l.times.length; i++)
                      // A gap in the data breaks the line.
                      l.values[i] == null
                          ? FlSpot.nullSpot
                          : FlSpot(x(l.times[i]), l.values[i]!),
                  ],
                  color: l.color,
                  barWidth: 2,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        l.color.withValues(alpha: 0.24),
                        l.color.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
