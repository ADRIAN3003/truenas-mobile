import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/instances/instances_provider.dart';
import '../../core/instances/server_instance.dart';
import '../../core/jobs/tracked_job.dart';
import '../../core/models/job.dart';
import '../../core/models/pool_summary.dart';
import '../../core/overview/server_overview.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/haptics.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../jobs/job_texts.dart';
import '../server/server_screen.dart';

/// Widest the list grows on tablets, so cards stay readable.
const _maxWidth = 640.0;

/// How often the overview looks at the servers again while it is open.
const _refreshEvery = Duration(seconds: 30);

/// Pools, alerts and running jobs of every saved server on one screen. A tap
/// on a server opens it.
class ServersOverviewScreen extends ConsumerStatefulWidget {
  const ServersOverviewScreen({super.key, this.loader});

  /// Looks at the servers; tests hand in one that talks to a fake.
  final ServerOverviewLoader? loader;

  @override
  ConsumerState<ServersOverviewScreen> createState() =>
      _ServersOverviewScreenState();
}

class _ServersOverviewScreenState extends ConsumerState<ServersOverviewScreen>
    with WidgetsBindingObserver {
  late final _loader = widget.loader ?? ServerOverviewLoader();
  final _entries = <String, OverviewEntry>{};
  Timer? _timer;
  var _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_refreshEvery, (_) => _refresh());
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_loader.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  List<ServerInstance> get _servers =>
      ref.read(instancesProvider).value ?? const [];

  Future<void> _refresh() async {
    // A pull to refresh while the timer's look is under way waits for it.
    if (_refreshing) return;
    _refreshing = true;
    try {
      await _loader.refresh(_servers, (entry) {
        if (mounted) setState(() => _entries[entry.server.id] = entry);
      });
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final servers = ref.watch(instancesProvider).value ?? const [];
    // Keep the saved order; a server added or removed since shows up on the
    // next look.
    final entries = [
      for (final server in servers)
        _entries[server.id]?.withServer(server) ?? OverviewEntry(server),
    ];
    final needAttention = entries
        .where(
          (e) =>
              e.problem != null ||
              (e.snapshot?.level ?? OverviewLevel.ok) != OverviewLevel.ok,
        )
        .length;
    final loaded = entries.every((e) => !e.loading);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.overviewTitle)),
      body: AppRefreshIndicator(
        onRefresh: _refresh,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                _Summary(
                  text: !loaded
                      ? null
                      : needAttention == 0
                      ? l10n.overviewAllFine
                      : l10n.overviewNeedAttention(needAttention),
                  good: needAttention == 0,
                  count: entries.length,
                ),
                for (final entry in entries) _ServerCard(entry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on OverviewEntry {
  /// The same result for the server as it is saved now (it may have been
  /// renamed since).
  OverviewEntry withServer(ServerInstance server) =>
      OverviewEntry(server, snapshot: snapshot, problem: problem);
}

class _Summary extends StatelessWidget {
  const _Summary({required this.text, required this.good, required this.count});

  final String? text;
  final bool good;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text ?? l10n.overviewTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: text != null && !good ? palette.warning : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.serversCount(count),
            style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard(this.entry);

  final OverviewEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final snapshot = entry.snapshot;
    final (label, tone) = switch (entry) {
      OverviewEntry(:final snapshot?) => switch (snapshot.level) {
        OverviewLevel.ok => (l10n.overviewLevelOk, StatusTone.good),
        OverviewLevel.attention => (
          l10n.overviewLevelAttention,
          StatusTone.warning,
        ),
        OverviewLevel.problem => (
          l10n.overviewLevelProblem,
          StatusTone.critical,
        ),
      },
      OverviewEntry(:final problem?) => (
        l10n.overviewLevelOffline,
        problem == OverviewProblem.unreachable
            ? StatusTone.critical
            : StatusTone.warning,
      ),
      _ => (null, StatusTone.neutral),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Haptics.selection();
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ServerScreen(entry.server.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconTile(
                      Icons.dns_rounded,
                      AppPalette.tileBlue,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.server.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (label != null)
                      StatusPill(label: label, tone: tone)
                    else
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      ),
                  ],
                ),
                if (snapshot != null) ...[
                  const SizedBox(height: 14),
                  _PoolsRow(snapshot),
                  const SizedBox(height: 8),
                  _AlertsRow(snapshot),
                  const SizedBox(height: 8),
                  _JobsSection(snapshot.jobs),
                ] else if (entry.problem != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    switch (entry.problem!) {
                      OverviewProblem.needsYou => l10n.overviewNeedsYou,
                      OverviewProblem.loginRejected =>
                        l10n.overviewLoginRejected,
                      OverviewProblem.unreachable => l10n.overviewUnreachable,
                    },
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An icon and a line of text, tinted by how much it matters.
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.text, required this.tone});

  final IconData icon;
  final String text;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = tone == StatusTone.neutral
        ? palette.muted
        : palette.tone(tone).$1;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tone == StatusTone.neutral ? palette.muted : color,
              fontWeight: tone == StatusTone.neutral ? null : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PoolsRow extends StatelessWidget {
  const _PoolsRow(this.snapshot);

  final ServerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final attention = snapshot.poolsNeedingAttention;
    final down = snapshot.pools.any((p) => p.condition == PoolCondition.down);
    return _Row(
      icon: Icons.storage_rounded,
      text: snapshot.pools.isEmpty
          ? l10n.overviewNoPools
          : attention == 0
          ? l10n.overviewPoolsHealthy(snapshot.pools.length)
          : l10n.overviewPoolsAttention(attention),
      tone: snapshot.pools.isEmpty
          ? StatusTone.neutral
          : down
          ? StatusTone.critical
          : attention > 0
          ? StatusTone.warning
          : StatusTone.good,
    );
  }
}

class _AlertsRow extends StatelessWidget {
  const _AlertsRow(this.snapshot);

  final ServerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = snapshot.alerts.length;
    final critical = snapshot.criticalAlerts;
    return _Row(
      icon: Icons.notifications_rounded,
      text: count == 0
          ? l10n.overviewNoAlerts
          : [
              l10n.overviewAlerts(count),
              if (critical > 0) l10n.overviewAlertsCritical(critical),
            ].join(' · '),
      tone: critical > 0
          ? StatusTone.critical
          : snapshot.warningAlerts > 0
          ? StatusTone.warning
          : count == 0
          ? StatusTone.good
          : StatusTone.info,
    );
  }
}

class _JobsSection extends StatelessWidget {
  const _JobsSection(this.jobs);

  final List<TrueNasJob> jobs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (jobs.isEmpty) {
      return _Row(
        icon: Icons.sync_rounded,
        text: l10n.overviewNoJobs,
        tone: StatusTone.neutral,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final job in jobs) _JobLine(job)],
    );
  }
}

class _JobLine extends StatelessWidget {
  const _JobLine(this.job);

  final TrueNasJob job;

  /// "Scrub · tank" for a job the app knows, else the server's description.
  String _title(AppLocalizations l10n) {
    final tracked = TrackedJob.of(job);
    if (tracked == null) return job.title;
    final name = l10n.jobKindName(tracked.kind);
    return tracked.target == null ? name : '$name · ${tracked.target}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final running = job.state == JobState.running;
    final percent = job.percent;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync_rounded, size: 18, color: palette.info),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _title(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                running && percent != null
                    ? '${percent.clamp(0, 100).round()} %'
                    : running
                    ? l10n.jobStateRunning
                    : l10n.jobStateWaiting,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                ),
              ),
            ],
          ),
          if (running) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: LinearProgressIndicator(
                value: percent == null ? null : percent.clamp(0.0, 100.0) / 100,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
