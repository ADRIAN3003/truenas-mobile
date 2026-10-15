import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/models/alert.dart';
import '../../core/models/pool_summary.dart';
import '../../core/models/realtime_stats.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/formatting.dart';
import '../../shared/viz_colors.dart';
import '../../shared/widgets.dart';

/// Number of live samples kept for the charts (2 minutes at 2 s each).
const _historyLength = 60;

/// Live overview of one server: system, CPU, memory, network, pools, alerts.
class DashboardTab extends StatefulWidget {
  const DashboardTab({
    super.key,
    required this.session,
    required this.info,
    required this.onOpenAlerts,
  });

  final TrueNasSession session;
  final Map<String, dynamic> info;
  final VoidCallback onOpenAlerts;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _history = <RealtimeStats>[];
  StreamSubscription<RealtimeStats>? _realtime;
  StreamSubscription<Object?>? _alertChanges;
  List<PoolSummary>? _pools;
  List<TrueNasAlert>? _alerts;

  @override
  void initState() {
    super.initState();
    _realtime = widget.session.realtimeStats().listen(
      (stats) => setState(() {
        _history.add(stats);
        if (_history.length > _historyLength) _history.removeAt(0);
      }),
      onError: (_) {},
    );
    _alertChanges = widget.session.alertChanges().listen(
      (_) => _loadAlerts(),
      onError: (_) {},
    );
    _refresh();
  }

  @override
  void dispose() {
    _realtime?.cancel();
    _alertChanges?.cancel();
    super.dispose();
  }

  Future<void> _refresh() => Future.wait([_loadPools(), _loadAlerts()]);

  Future<void> _loadPools() async {
    try {
      final pools = await widget.session.pools();
      if (mounted) setState(() => _pools = pools);
    } catch (_) {
      if (mounted) setState(() => _pools = const []);
    }
  }

  Future<void> _loadAlerts() async {
    try {
      final alerts = await widget.session.alerts();
      if (mounted) setState(() => _alerts = alerts);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final latest = _history.isEmpty ? null : _history.last;
    final system = [
      _SystemCard(info: widget.info, session: widget.session),
      if (_alerts != null)
        _AlertsSummaryCard(alerts: _alerts!, onTap: widget.onOpenAlerts),
    ];
    final live = latest == null
        ? [const _WaitingCard()]
        : [
            _CpuCard(history: _history),
            _MemoryCard(stats: latest),
            _NetworkCard(history: _history),
          ];
    final pools = [if (_pools != null) _PoolsCard(pools: _pools!)];
    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: constraints.maxWidth < 840
              ? [...system, ...live, ...pools]
              // Two columns on wide screens: system and pools beside the
              // live charts.
              : [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(children: [...system, ...pools])),
                      const SizedBox(width: 16),
                      Expanded(child: Column(children: live)),
                    ],
                  ),
                ],
        ),
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  const _DashCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SystemCard extends StatelessWidget {
  const _SystemCard({required this.info, required this.session});

  final Map<String, dynamic> info;
  final TrueNasSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final uptime = info['uptime_seconds'];
    final memory = info['physmem'];
    final facts = <(String, String?)>[
      (l10n.infoVersion, info['version']?.toString()),
      (l10n.infoApiVersion, session.apiVersion),
      (
        l10n.infoUptime,
        uptime is num
            ? formatDuration(Duration(seconds: uptime.round()))
            : null,
      ),
      (l10n.infoModel, info['model']?.toString()),
      (l10n.infoCores, info['cores']?.toString()),
      (l10n.infoMemory, memory is num ? formatBytes(memory) : null),
      (l10n.infoSignedInAs, session.userInfo?['pw_name']?.toString()),
    ];
    return _DashCard(
      title: info['hostname']?.toString() ?? l10n.systemTitle,
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          for (final (label, value) in facts)
            if (value != null && value.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(value, style: theme.textTheme.bodyMedium),
                ],
              ),
        ],
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard();

  @override
  Widget build(BuildContext context) => _DashCard(
    title: AppLocalizations.of(context).cpuTitle,
    child: Row(
      children: [
        const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(AppLocalizations.of(context).liveWaiting)),
      ],
    ),
  );
}

class _CpuCard extends StatelessWidget {
  const _CpuCard({required this.history});

  final List<RealtimeStats> history;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final latest = history.last;
    final temperature = latest.cpuTemperature;
    return _DashCard(
      title: l10n.cpuTitle,
      trailing: temperature == null
          ? null
          : Text(
              l10n.cpuTemperature(temperature.toStringAsFixed(0)),
              style: theme.textTheme.bodyMedium,
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              '${latest.cpuPercent.round()}%',
              style: theme.textTheme.displaySmall,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Sparkline(
              series: [
                _Series(
                  l10n.cpuTitle,
                  VizColors.of(context).series1,
                  history.map((e) => e.cpuPercent).toList(),
                ),
              ],
              maxY: 100,
              formatValue: (v) => '${v.round()}%',
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.stats});

  final RealtimeStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = VizColors.of(context);
    final total = math.max(stats.memoryTotal, 1);
    final arc = stats.arcSize.clamp(0, stats.memoryUsed);
    final services = math.max(stats.memoryUsed - arc, 0);
    final free = math.max(total - services - arc, 0);
    return _DashCard(
      title: l10n.memoryTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.memoryUsedOf(
              formatBytes(stats.memoryUsed),
              formatBytes(stats.memoryTotal),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedBar(
            segments: [
              (services / total, colors.series1),
              (arc / total, colors.series2),
              (free / total, colors.track),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              LegendItem(
                colors.series1,
                '${l10n.memoryServices} ${formatBytes(services)}',
              ),
              LegendItem(
                colors.series2,
                '${l10n.memoryArc} ${formatBytes(arc)}',
              ),
              LegendItem(
                colors.track,
                '${l10n.memoryFree} ${formatBytes(free)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({required this.history});

  final List<RealtimeStats> history;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = VizColors.of(context);
    final latest = history.last;
    return _DashCard(
      title: l10n.networkTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            children: [
              LegendItem(
                colors.series1,
                '${l10n.networkIn} ${formatBitRate(latest.receivedBytesPerSecond)}',
              ),
              LegendItem(
                colors.series2,
                '${l10n.networkOut} ${formatBitRate(latest.sentBytesPerSecond)}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Sparkline(
            series: [
              _Series(
                l10n.networkIn,
                colors.series1,
                history.map((e) => e.receivedBytesPerSecond).toList(),
              ),
              _Series(
                l10n.networkOut,
                colors.series2,
                history.map((e) => e.sentBytesPerSecond).toList(),
              ),
            ],
            formatValue: formatBitRate,
          ),
        ],
      ),
    );
  }
}

class _PoolsCard extends StatelessWidget {
  const _PoolsCard({required this.pools});

  final List<PoolSummary> pools;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VizColors.of(context);
    return _DashCard(
      title: l10n.poolsTitle,
      child: pools.isEmpty
          ? Text(l10n.poolsEmpty)
          : Column(
              children: [
                for (final pool in pools)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                pool.name,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            StatusLabel(
                              icon: pool.healthy
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: pool.healthy
                                  ? VizColors.good
                                  : VizColors.critical,
                              label: pool.status,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SegmentedBar(
                          segments: [
                            (pool.usedFraction, colors.series1),
                            (1 - pool.usedFraction, colors.track),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.poolUsage(
                            formatBytes(pool.allocated),
                            formatBytes(pool.size),
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _AlertsSummaryCard extends StatelessWidget {
  const _AlertsSummaryCard({required this.alerts, required this.onTap});

  final List<TrueNasAlert> alerts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = alerts.where((a) => !a.dismissed);
    int count(AlertSeverity s) =>
        active.where((a) => a.level.severity == s).length;
    final critical = count(AlertSeverity.critical);
    final warning = count(AlertSeverity.warning);
    final info = count(AlertSeverity.info);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: _DashCard(
        title: l10n.alertsTitle,
        trailing: const Icon(Icons.chevron_right),
        child: active.isEmpty
            ? StatusLabel(
                icon: Icons.check_circle,
                color: VizColors.good,
                label: l10n.alertsNone,
              )
            : Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (critical > 0)
                    StatusLabel(
                      icon: Icons.error,
                      color: VizColors.critical,
                      label: l10n.alertsCritical(critical),
                    ),
                  if (warning > 0)
                    StatusLabel(
                      icon: Icons.warning_amber,
                      color: VizColors.warning,
                      label: l10n.alertsWarning(warning),
                    ),
                  if (info > 0)
                    StatusLabel(
                      icon: Icons.info_outline,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      label: l10n.alertsInfo(info),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Series {
  const _Series(this.name, this.color, this.values);

  final String name;
  final Color color;
  final List<double> values;
}

/// A small line chart of recent samples with a touch tooltip.
class _Sparkline extends StatelessWidget {
  const _Sparkline({
    required this.series,
    required this.formatValue,
    this.maxY,
  });

  final List<_Series> series;
  final String Function(double) formatValue;
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peak = series
        .expand((s) => s.values)
        .fold<double>(0, (a, b) => math.max(a, b));
    // The values are also shown as text, so screen readers skip the chart.
    return ExcludeSemantics(
      child: SizedBox(
        height: 72,
        child: LineChart(
          duration: Duration.zero,
          LineChartData(
            minX: 0,
            maxX: (_historyLength - 1).toDouble(),
            minY: 0,
            maxY: maxY ?? (peak <= 0 ? 1 : peak * 1.15),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    LineTooltipItem(
                      '${series[spot.barIndex].name} ${formatValue(spot.y)}',
                      TextStyle(color: theme.colorScheme.onInverseSurface),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              for (final s in series)
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < s.values.length; i++)
                      FlSpot(
                        (_historyLength - s.values.length + i).toDouble(),
                        s.values[i],
                      ),
                  ],
                  color: s.color,
                  barWidth: 2,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  dotData: const FlDotData(show: false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
