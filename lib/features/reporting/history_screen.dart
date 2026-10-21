import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/reporting.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/dialogs.dart';
import '../../shared/formatting.dart';
import '../../shared/ui.dart';
import '../../shared/viz_colors.dart';
import '../../shared/widgets.dart';
import '../storage/storage_helpers.dart';
import 'history_chart.dart';

/// The graphs this screen draws, in order.
const _graphNames = ['cpu', 'cputemp', 'interface', 'arcsize', 'disktemp'];

/// One graph's answer: the samples per interface or disk, or why not.
typedef _Section = ({List<ReportingData>? data, Object? error});

/// CPU, network, disk temperature and ARC over the last hour, day, week or
/// month, from the server's reporting.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  ReportingRange _range = ReportingRange.day;
  Map<String, ReportingGraph>? _graphs;
  Object? _error;
  bool _available = true;

  /// By graph name; missing while that graph is loading.
  final _sections = <String, _Section>{};
  String? _interface;
  String? _disk;

  /// Bumped on every load, so an answer to an older one is dropped.
  int _generation = 0;
  StreamSubscription<void>? _reconnects;

  @override
  void initState() {
    super.initState();
    _reconnects = widget.session.reconnected.listen((_) => _load());
    _load();
  }

  @override
  void dispose() {
    _reconnects?.cancel();
    super.dispose();
  }

  /// Loads everything; [keep] leaves the charts on screen until the new data
  /// is there (pull to refresh), otherwise they show a spinner.
  Future<void> _load({bool keep = false}) async {
    final generation = ++_generation;
    if (!keep) setState(_sections.clear);
    try {
      final api = widget.session.reporting;
      if (!await api.isAvailable()) {
        if (mounted) setState(() => _available = false);
        return;
      }
      final graphs = {for (final g in await api.graphs()) g.name: g};
      if (!mounted || generation != _generation) return;
      setState(() {
        _available = true;
        _graphs = graphs;
        _error = null;
      });
      await Future.wait([
        for (final name in _graphNames)
          if (graphs.containsKey(name)) _loadSection(graphs[name]!, generation),
      ]);
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    }
  }

  Future<void> _loadSection(ReportingGraph graph, int generation) async {
    _Section section;
    try {
      // One request for every interface or disk, so switching is instant.
      final requests = graph.identifiers.isEmpty
          ? [(name: graph.name, identifier: null as String?)]
          : [
              for (final id in graph.identifiers)
                (name: graph.name, identifier: id as String?),
            ];
      section = (
        data: await widget.session.reporting.data(requests, _range),
        error: null,
      );
    } catch (e) {
      section = (data: null, error: e);
    }
    if (!mounted || generation != _generation) return;
    setState(() => _sections[graph.name] = section);
  }

  void _setRange(ReportingRange range) {
    if (range == _range) return;
    _range = range;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final graphs = _graphs;
    final Widget body;
    if (!_available) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(l10n.historyUnavailable, textAlign: TextAlign.center),
        ),
      );
    } else {
      body = AsyncBody<Map<String, ReportingGraph>>(
        value: graphs,
        error: _error,
        onRefresh: () => _load(keep: true),
        builder: (graphs) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            AppSegments<ReportingRange>(
              values: ReportingRange.values,
              labels: [
                l10n.historyRangeHour,
                l10n.historyRangeDay,
                l10n.historyRangeWeek,
                l10n.historyRangeMonth,
              ],
              selected: _range,
              onChanged: _setRange,
            ),
            const SizedBox(height: 8),
            if (graphs.containsKey('cpu')) _cpuCard(l10n),
            if (_hasData('cputemp')) _cpuTemperatureCard(l10n),
            if (graphs.containsKey('interface')) _networkCard(l10n),
            if (graphs.containsKey('arcsize')) _arcCard(l10n),
            if (_hasData('disktemp')) _diskCard(l10n),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: body,
    );
  }

  /// A graph whose card is only worth showing once it has samples (a VM has
  /// no sensors), so it stays out while loading and when it is empty.
  bool _hasData(String name) {
    if (_graphs?.containsKey(name) != true) return false;
    final data = _sections[name]?.data;
    return data != null && data.any((d) => !d.isEmpty);
  }

  Widget _cpuCard(AppLocalizations l10n) {
    final colors = VizColors.of(context);
    return _card(
      l10n,
      icon: Icons.speed_rounded,
      title: l10n.cpuTitle,
      name: 'cpu',
      builder: (data) {
        final d = data.first;
        return _chart(
          l10n,
          [ChartLine(l10n.cpuTitle, colors.series1, d.times, d.cpuUsage())],
          (v) => '${v.round()}%',
          maxY: 100,
        );
      },
    );
  }

  Widget _cpuTemperatureCard(AppLocalizations l10n) {
    final colors = VizColors.of(context);
    return _card(
      l10n,
      icon: Icons.thermostat_rounded,
      title: l10n.historyCpuTemperature,
      name: 'cputemp',
      builder: (data) {
        final d = data.first;
        return _chart(
          l10n,
          [
            ChartLine(
              l10n.historyCpuTemperature,
              colors.series2,
              d.times,
              d.mean(),
            ),
          ],
          (v) => l10n.cpuTemperature(v.toStringAsFixed(0)),
          zeroBased: false,
        );
      },
    );
  }

  Widget _networkCard(AppLocalizations l10n) {
    final colors = VizColors.of(context);
    final graph = _graphs!['interface']!;
    // Kilobits per second unless the label says otherwise.
    final scale = bytesPerUnit(graph.verticalLabel, 125);
    return _card(
      l10n,
      icon: Icons.swap_vert_rounded,
      title: l10n.networkTitle,
      name: 'interface',
      selected: _interface,
      pickerLabel: l10n.historyInterface,
      onPick: (id) => setState(() => _interface = id),
      busiest: (d) {
        var total = 0.0;
        for (final column in d.columns) {
          total += SeriesStats.of(column.map((v) => v?.abs()))?.average ?? 0;
        }
        return total;
      },
      builder: (data) {
        final d = data.first;
        List<double?> rate(String column) => [
          for (final v
              in d.column(column) ?? List<double?>.filled(d.times.length, null))
            v == null ? null : v.abs() * scale,
        ];
        return _chart(l10n, [
          ChartLine(l10n.networkIn, colors.series1, d.times, rate('received')),
          ChartLine(l10n.networkOut, colors.series2, d.times, rate('sent')),
        ], formatBitRate);
      },
    );
  }

  Widget _arcCard(AppLocalizations l10n) {
    final colors = VizColors.of(context);
    final graph = _graphs!['arcsize']!;
    // Mebibytes unless the label says otherwise.
    final scale = bytesPerUnit(graph.verticalLabel, 1048576);
    return _card(
      l10n,
      icon: Icons.memory_rounded,
      title: l10n.historyArc,
      name: 'arcsize',
      builder: (data) {
        final d = data.first;
        final column =
            d.column('arc_size') ?? d.column('arcsz') ?? d.columns.first;
        return _chart(l10n, [
          ChartLine(l10n.memoryArc, colors.series2, d.times, [
            for (final v in column) v == null ? null : v * scale,
          ]),
        ], formatBytes);
      },
    );
  }

  Widget _diskCard(AppLocalizations l10n) {
    final colors = VizColors.of(context);
    return _card(
      l10n,
      icon: Icons.thermostat_rounded,
      title: l10n.historyDiskTemperature,
      name: 'disktemp',
      selected: _disk,
      pickerLabel: l10n.historyDisk,
      onPick: (id) => setState(() => _disk = id),
      busiest: (d) => SeriesStats.of(d.mean())?.peak ?? 0,
      builder: (data) {
        final d = data.first;
        return _chart(
          l10n,
          [
            ChartLine(
              d.identifier ?? l10n.historyDiskTemperature,
              colors.series2,
              d.times,
              d.mean(),
            ),
          ],
          (v) => l10n.cpuTemperature(v.toStringAsFixed(0)),
          zeroBased: false,
        );
      },
    );
  }

  /// A card for the graph [name]. With [selected] and [onPick] it has a picker
  /// over its series (interfaces, disks): the one called [selected], or the
  /// one [busiest] ranks highest. [builder] gets that series alone.
  Widget _card(
    AppLocalizations l10n, {
    required IconData icon,
    required String title,
    required String name,
    required Widget Function(List<ReportingData> data) builder,
    String? selected,
    String? pickerLabel,
    ValueChanged<String>? onPick,
    double Function(ReportingData)? busiest,
  }) {
    final theme = Theme.of(context);
    final section = _sections[name];
    Widget child;
    Widget? picker;
    if (section == null) {
      child = const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    } else if (section.error != null) {
      child = Text(l10n.historyChartFailed);
    } else {
      final all = [
        for (final d in section.data!)
          if (!d.isEmpty) d,
      ];
      if (all.isEmpty) {
        child = Text(l10n.historyNoData);
      } else {
        var current = all.first;
        if (onPick != null) {
          final chosen = all.where((d) => d.identifier == selected);
          if (chosen.isNotEmpty) {
            current = chosen.first;
          } else {
            current = all.reduce((a, b) => busiest!(b) > busiest(a) ? b : a);
          }
          if (all.length > 1) {
            picker = _Picker(
              label: pickerLabel!,
              value: current.identifier ?? '',
              options: [for (final d in all) d.identifier ?? ''],
              onPick: onPick,
            );
          }
        }
        child = builder([current]);
      }
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                ?picker,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  /// The chart and, under it, each line's average and peak.
  Widget _chart(
    AppLocalizations l10n,
    List<ChartLine> lines,
    String Function(double) format, {
    double? maxY,
    bool zeroBased = true,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HistoryChart(
          lines: lines,
          range: _range,
          formatValue: format,
          maxY: maxY,
          zeroBased: zeroBased,
        ),
        const SizedBox(height: 10),
        for (final line in lines)
          if (SeriesStats.of(line.values) case final stats?)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  if (lines.length > 1) ...[
                    // The same width for every line keeps the figures aligned.
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 64),
                      child: LegendItem(line.color, line.name),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      l10n.historyStats(
                        format(stats.average),
                        format(stats.peak),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// "Interface eno1 ▾": opens a list to pick another.
class _Picker extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.value,
    required this.options,
    required this.onPick,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final choice = await showAppChoice<String>(
          context: context,
          title: label,
          dialogOnAndroid: true,
          choices: [
            for (final o in options) appChoice(o, o, selected: o == value),
          ],
        );
        if (choice != null) onPick(choice.$1);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label $value',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
