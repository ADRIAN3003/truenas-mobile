import 'dart:async';
import 'dart:ui';

import '../../l10n/generated/app_localizations.dart';
import '../instances/server_instance.dart';
import '../models/alert.dart';
import '../models/realtime_stats.dart';
import '../session/truenas_session.dart';
import 'home_widget_data.dart';
import 'home_widgets.dart';

/// The strings for [locale], or English for a language the app lacks. The
/// background check has no `BuildContext` to ask.
AppLocalizations localizationsFor(Locale locale) =>
    AppLocalizations.delegate.isSupported(locale)
    ? lookupAppLocalizations(locale)
    : lookupAppLocalizations(const Locale('en'));

/// Gathers what the widgets show from servers that are open or have just
/// been checked, then saves it all at once with [finish] (several servers are
/// looked at side by side, and each save reads the last one first).
class HomeWidgetCollector {
  HomeWidgetCollector({
    required this.publisher,
    required this.locale,
    this.chosenDefault,
    this.statsTimeout = const Duration(seconds: 6),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final HomeWidgetPublisher publisher;
  final Locale Function() locale;

  /// The `defaultServerId` setting: the server a widget shows when the user
  /// has not picked one.
  final String? chosenDefault;

  /// How long to wait for the first `reporting.realtime` sample (they come
  /// every 2 seconds).
  final Duration statsTimeout;
  final DateTime Function() _now;

  final _fresh = <String, Map<String, dynamic>>{};
  final _unreachable = <String>{};

  /// Reads the pools and the live statistics of [server] through [session].
  /// [alerts] is what was just fetched, if anything was. A server that does
  /// not answer is marked unreachable; this never throws.
  Future<void> collect(
    ServerInstance server,
    TrueNasSession session, {
    List<TrueNasAlert>? alerts,
  }) async {
    try {
      final (pools, current, stats) = await (
        session.pools(),
        alerts == null ? session.alerts() : Future.value(alerts),
        _stats(session),
      ).wait;
      _fresh[server.id] = serverWidgetData(
        server: server,
        now: _now(),
        pools: pools,
        alerts: current,
        stats: stats,
        l10n: localizationsFor(locale()),
      );
    } catch (_) {
      _unreachable.add(server.id);
    }
  }

  /// One sample of CPU and memory, or null on a server that does not send
  /// them (the widget then shows only what it has).
  Future<RealtimeStats?> _stats(TrueNasSession session) async {
    try {
      return await session.realtimeStats().first.timeout(statsTimeout);
    } catch (_) {
      return null;
    }
  }

  void markUnreachable(ServerInstance server) {
    if (!_fresh.containsKey(server.id)) _unreachable.add(server.id);
  }

  Future<void> finish(List<ServerInstance> servers) => publisher.publish(
    servers: servers,
    fresh: _fresh,
    unreachable: _unreachable,
    labels: homeWidgetLabels(localizationsFor(locale())),
    chosenDefault: chosenDefault,
  );
}

/// Keeps the widgets up to date while a server is open in the app: now, then
/// every [interval], and whenever [refresh] is called (the app was left or
/// came back).
class HomeWidgetSync {
  HomeWidgetSync({
    required this.publisher,
    required this.session,
    required this.server,
    required this.servers,
    required this.locale,
    required this.chosenDefault,
    this.interval = const Duration(minutes: 1),
  });

  final HomeWidgetPublisher publisher;
  final TrueNasSession session;
  final ServerInstance Function() server;
  final List<ServerInstance> Function() servers;
  final Locale Function() locale;
  final String? Function() chosenDefault;
  final Duration interval;

  Timer? _timer;
  Future<void>? _running;
  var _disposed = false;

  void start() {
    unawaited(refresh());
    _timer = Timer.periodic(interval, (_) => unawaited(refresh()));
  }

  /// Looks again now. A look already under way is not repeated.
  Future<void> refresh() =>
      _running ??= _refresh().whenComplete(() => _running = null);

  Future<void> _refresh() async {
    if (_disposed) return;
    final collector = HomeWidgetCollector(
      publisher: publisher,
      locale: locale,
      chosenDefault: chosenDefault(),
    );
    await collector.collect(server(), session);
    if (!_disposed) await collector.finish(servers());
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}
