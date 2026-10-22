import '../../l10n/generated/app_localizations.dart';
import '../../shared/formatting.dart';
import '../instances/server_instance.dart';
import '../models/alert.dart';
import '../models/pool_summary.dart';
import '../models/realtime_stats.dart';

/// How the widgets colour a value: green, orange or red.
enum WidgetLevel { ok, warn, bad }

/// What the home screen widgets show about one server, as the JSON the
/// native widgets read. Text is already in the user's language and plurals
/// are already worked out, so the Swift and Kotlin sides only draw it.
///
/// Every part is optional: a server that has not answered yet has none, and
/// the widget says so.
Map<String, dynamic> serverWidgetData({
  required ServerInstance server,
  required DateTime now,
  required List<PoolSummary> pools,
  required List<TrueNasAlert> alerts,
  required RealtimeStats? stats,
  required AppLocalizations l10n,
}) {
  final active = [
    for (final alert in alerts)
      if (!alert.dismissed) alert,
  ]..sort((a, b) => b.level.index.compareTo(a.level.index));
  final critical = active
      .where((a) => a.level.severity == AlertSeverity.critical)
      .length;
  final warning = active
      .where((a) => a.level.severity == AlertSeverity.warning)
      .length;
  final alertLevel = critical > 0
      ? WidgetLevel.bad
      : warning > 0
      ? WidgetLevel.warn
      : WidgetLevel.ok;

  final poolItems = [for (final pool in pools) _pool(pool)];
  final poolsAttention = poolItems.where((p) => p['level'] != 'ok').length;
  final poolsLevel = poolItems.any((p) => p['level'] == 'bad')
      ? WidgetLevel.bad
      : poolsAttention > 0
      ? WidgetLevel.warn
      : WidgetLevel.ok;

  return {
    'id': server.id,
    'name': server.name,
    'updatedAt': now.millisecondsSinceEpoch,
    'unreachable': false,
    'pools': {
      'level': poolsLevel.name,
      'summary': pools.isEmpty
          ? l10n.homeWidgetNoPools
          : poolsAttention == 0
          ? l10n.homeWidgetPoolsOk
          : l10n.homeWidgetPoolsAttention(poolsAttention),
      'items': poolItems,
    },
    if (stats != null)
      'system': {
        'cpu': _round(stats.cpuPercent),
        'memory': stats.memoryTotal == 0
            ? null
            : _round(stats.memoryUsed / stats.memoryTotal * 100),
        'memoryText': l10n.homeWidgetMemoryText(
          formatBytes(stats.memoryUsed),
          formatBytes(stats.memoryTotal),
        ),
        'temperature': stats.cpuTemperature == null
            ? null
            : '${stats.cpuTemperature!.round()} °C',
      },
    'alerts': {
      'level': alertLevel.name,
      'count': active.length,
      'summary': active.isEmpty
          ? l10n.homeWidgetAlertsNone
          : l10n.homeWidgetAlertsCount(active.length),
      'items': [
        for (final alert in active.take(_maxAlerts))
          {
            'level': switch (alert.level.severity) {
              AlertSeverity.critical => WidgetLevel.bad.name,
              AlertSeverity.warning => WidgetLevel.warn.name,
              AlertSeverity.info => WidgetLevel.ok.name,
            },
            'text': _shorten(alert.plainMessage),
          },
      ],
    },
  };
}

/// How many alert lines a widget can use.
const _maxAlerts = 4;

/// A pool is orange when it is nearly full or not entirely healthy, and red
/// when ZFS says it is down or faulted.
Map<String, dynamic> _pool(PoolSummary pool) {
  final status = pool.status.toUpperCase();
  final level = switch (status) {
    'ONLINE' =>
      !pool.healthy || pool.usedFraction >= 0.9
          ? WidgetLevel.warn
          : WidgetLevel.ok,
    'DEGRADED' => WidgetLevel.warn,
    _ => WidgetLevel.bad,
  };
  return {
    'name': pool.name,
    'status': status,
    'used': _round(pool.usedFraction.clamp(0.0, 1.0).toDouble() * 100),
    'level': level.name,
  };
}

double _round(double value) => (value * 10).round() / 10;

/// Widgets have little room: the first line or so of an alert.
String _shorten(String text) {
  final line = text.split('\n').first.trim();
  return line.length <= 110 ? line : '${line.substring(0, 109).trimRight()}…';
}

/// A plural message as a template with `{count}` in it, for a widget that
/// works the count out itself (the iOS ones fetch their own data).
String _countTemplate(String Function(int count) message) =>
    message(2).replaceFirst('2', '{count}');

/// The words the widgets use for everything that is not about one server.
Map<String, String> homeWidgetLabels(AppLocalizations l10n) => {
  'pools': l10n.homeWidgetPools,
  'system': l10n.homeWidgetSystem,
  'alerts': l10n.homeWidgetAlerts,
  'cpu': l10n.homeWidgetCpu,
  'memory': l10n.homeWidgetMemory,
  'updated': l10n.homeWidgetUpdated,
  'unreachable': l10n.homeWidgetUnreachable,
  'setup': l10n.homeWidgetSetup,
  'noData': l10n.homeWidgetNoData,
  'noPools': l10n.homeWidgetNoPools,
  'poolsOk': l10n.homeWidgetPoolsOk,
  'poolsAttentionOne': l10n.homeWidgetPoolsAttention(1),
  'poolsAttentionMany': _countTemplate(l10n.homeWidgetPoolsAttention),
  'alertsNone': l10n.homeWidgetAlertsNone,
  'alertsCountOne': l10n.homeWidgetAlertsCount(1),
  'alertsCountMany': _countTemplate(l10n.homeWidgetAlertsCount),
  'memoryText': l10n.homeWidgetMemoryText('{used}', '{total}'),
};
