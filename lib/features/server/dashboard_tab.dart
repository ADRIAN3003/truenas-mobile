import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/models/alert.dart';
import '../../core/models/pool_summary.dart';
import '../../core/models/realtime_stats.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glass.dart';
import '../../shared/formatting.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
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
      _ServerHeader(info: widget.info, session: widget.session),
      if (_alerts != null)
        _AlertsBanner(alerts: _alerts!, onTap: widget.onOpenAlerts),
    ];
    final live = latest == null
        ? [const _WaitingCard()]
        : [_GaugesCard(history: _history), _NetworkCard(history: _history)];
    final pools = [if (_pools != null) _PoolsCard(pools: _pools!)];
    return RefreshIndicator.adaptive(
      edgeOffset: ChromeInsets.of(context).top,
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: ChromeInsets.pad(
            context,
            const EdgeInsets.fromLTRB(16, 4, 16, 24),
          ),
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
  const _DashCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
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
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// The server's name, connection state and key facts on a blue gradient.
class _ServerHeader extends StatelessWidget {
  const _ServerHeader({required this.info, required this.session});

  final Map<String, dynamic> info;
  final TrueNasSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final uptime = info['uptime_seconds'];
    final memory = info['physmem'];
    final cores = info['cores'];
    final model = info['model']?.toString();
    final facts = <(String, String?)>[
      (l10n.infoVersion, info['version']?.toString()),
      (l10n.infoApiVersion, session.apiVersion),
      (
        l10n.infoUptime,
        uptime is num
            ? formatDuration(Duration(seconds: uptime.round()))
            : null,
      ),
      (l10n.infoMemory, memory is num ? formatBytes(memory) : null),
      (l10n.infoCores, cores?.toString()),
      (l10n.infoSignedInAs, session.userInfo?['pw_name']?.toString()),
    ];
    const onHero = Colors.white;
    final onHeroMuted = Colors.white.withValues(alpha: 0.72);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.heroStart, palette.heroEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.dns_rounded, color: onHero),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info['hostname']?.toString() ?? l10n.systemTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: onHero,
                      ),
                    ),
                    if (model != null && model.isNotEmpty)
                      Text(
                        model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onHeroMuted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF5BE38C),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.dashboardConnected,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: onHero,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              // Three facts per row, evenly spaced.
              final width = (constraints.maxWidth - 2 * 12) / 3;
              return Wrap(
                spacing: 12,
                runSpacing: 14,
                children: [
                  for (final (label, value) in facts)
                    if (value != null && value.isNotEmpty)
                      SizedBox(
                        width: width,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: onHeroMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: onHero,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              );
            },
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
    icon: Icons.speed_rounded,
    title: AppLocalizations.of(context).cpuTitle,
    child: Row(
      children: [
        const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(AppLocalizations.of(context).liveWaiting)),
      ],
    ),
  );
}

/// CPU and memory rings, with the CPU history underneath.
class _GaugesCard extends StatelessWidget {
  const _GaugesCard({required this.history});

  final List<RealtimeStats> history;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VizColors.of(context);
    final stats = history.last;
    final total = math.max(stats.memoryTotal, 1);
    final arc = stats.arcSize.clamp(0, stats.memoryUsed);
    final services = math.max(stats.memoryUsed - arc, 0);
    final temperature = stats.cpuTemperature;
    final big = theme.textTheme.headlineSmall;
    final caption = theme.textTheme.bodySmall;

    Widget gauge({
      required String title,
      required List<(double, Color)> segments,
      required String value,
      required String detail,
    }) => Column(
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        RingGauge(
          segments: segments,
          child: Text(value, style: big),
        ),
        const SizedBox(height: 8),
        Text(detail, style: caption, textAlign: TextAlign.center),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: gauge(
                    title: l10n.cpuTitle,
                    segments: [(stats.cpuPercent / 100, colors.series1)],
                    value: '${stats.cpuPercent.round()}%',
                    detail: temperature == null
                        ? ''
                        : l10n.cpuTemperature(temperature.toStringAsFixed(0)),
                  ),
                ),
                Expanded(
                  child: gauge(
                    title: l10n.memoryTitle,
                    segments: [
                      (services / total, colors.series1),
                      (arc / total, colors.series2),
                    ],
                    value: '${(stats.memoryUsed / total * 100).round()}%',
                    detail: l10n.poolUsage(
                      formatBytes(stats.memoryUsed),
                      formatBytes(stats.memoryTotal),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                LegendItem(
                  colors.series1,
                  '${l10n.memoryServices} ${formatBytes(services)}',
                ),
                LegendItem(
                  colors.series2,
                  '${l10n.memoryArc} ${formatBytes(arc)}',
                ),
              ],
            ),
            // A line needs two samples; the history fills in within seconds.
            if (history.length > 1) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(l10n.cpuTitle, style: theme.textTheme.labelMedium),
                  const Spacer(),
                  Text(
                    '${stats.cpuPercent.round()}%',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _Sparkline(
                series: [
                  _Series(
                    l10n.cpuTitle,
                    colors.series1,
                    history.map((e) => e.cpuPercent).toList(),
                  ),
                ],
                maxY: 100,
                formatValue: (v) => '${v.round()}%',
              ),
            ],
          ],
        ),
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
    final theme = Theme.of(context);
    final colors = VizColors.of(context);
    final latest = history.last;

    Widget rate(IconData icon, Color color, String label, double value) => Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              Text(
                formatBitRate(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ],
    );

    return _DashCard(
      icon: Icons.swap_vert_rounded,
      title: l10n.networkTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: rate(
                  Icons.south_rounded,
                  colors.series1,
                  l10n.networkIn,
                  latest.receivedBytesPerSecond,
                ),
              ),
              Expanded(
                child: rate(
                  Icons.north_rounded,
                  colors.series2,
                  l10n.networkOut,
                  latest.sentBytesPerSecond,
                ),
              ),
            ],
          ),
          if (history.length > 1) ...[
            const SizedBox(height: 14),
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
      icon: Icons.storage_rounded,
      title: l10n.poolsTitle,
      child: pools.isEmpty
          ? Text(l10n.poolsEmpty)
          : Column(
              children: [
                for (final (i, pool) in pools.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                pool.name,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            StatusPill(
                              label: pool.status,
                              tone: pool.healthy
                                  ? StatusTone.good
                                  : StatusTone.critical,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SegmentedBar(
                          height: 8,
                          segments: [
                            (pool.usedFraction, colors.series1),
                            (1 - pool.usedFraction, colors.track),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.poolUsage(
                                  formatBytes(pool.allocated),
                                  formatBytes(pool.size),
                                ),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            Text(
                              '${(pool.usedFraction * 100).round()}%',
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// A tinted strip summarising active alerts by severity.
class _AlertsBanner extends StatelessWidget {
  const _AlertsBanner({required this.alerts, required this.onTap});

  final List<TrueNasAlert> alerts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final active = alerts.where((a) => !a.dismissed);
    int count(AlertSeverity s) =>
        active.where((a) => a.level.severity == s).length;
    final critical = count(AlertSeverity.critical);
    final warning = count(AlertSeverity.warning);
    final info = count(AlertSeverity.info);
    final (tone, icon) = critical > 0
        ? (StatusTone.critical, Icons.error_rounded)
        : warning > 0
        ? (StatusTone.warning, Icons.warning_rounded)
        : info > 0
        ? (StatusTone.info, Icons.info_rounded)
        : (StatusTone.good, Icons.check_circle_rounded);
    final (color, background) = palette.tone(tone);
    final summary = active.isEmpty
        ? l10n.alertsNone
        : [
            if (critical > 0) l10n.alertsCritical(critical),
            if (warning > 0) l10n.alertsWarning(warning),
            if (info > 0) l10n.alertsInfo(info),
          ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.alertsTitle, style: theme.textTheme.titleSmall),
                      Text(
                        summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Chevron(),
              ],
            ),
          ),
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
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        s.color.withValues(alpha: 0.28),
                        s.color.withValues(alpha: 0),
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
