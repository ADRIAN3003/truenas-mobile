import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/storage_api.dart';
import '../../core/models/storage.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/formatting.dart';
import '../../shared/viz_colors.dart';
import '../../shared/widgets.dart';
import 'datasets_screen.dart';
import 'storage_helpers.dart';

/// One pool: usage, scrub controls and vdev layout.
class PoolScreen extends StatefulWidget {
  const PoolScreen({super.key, required this.session, required this.poolId});

  final TrueNasSession session;
  final int poolId;

  @override
  State<PoolScreen> createState() => _PoolScreenState();
}

class _PoolScreenState extends State<PoolScreen> {
  PoolDetail? _pool;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pool = await widget.session.storage.pool(widget.poolId);
      if (!mounted) return;
      setState(() {
        _pool = pool;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _scrub(PoolDetail pool, ScrubAction action) async {
    final l10n = AppLocalizations.of(context);
    if (action == ScrubAction.stop &&
        !await confirmAction(
          context,
          title: l10n.scrubStopTitle(pool.name),
          body: l10n.scrubStopBody,
          confirmLabel: l10n.scrubStop,
          cancelLabel: l10n.cancel,
        )) {
      return;
    }
    if (!mounted) return;
    await runWithFeedback(
      context,
      () => widget.session.storage.scrub(pool.name, action),
      success: action == ScrubAction.start ? l10n.scrubStarted : null,
    );
    // The scan state updates a moment after the job starts.
    await Future<void>.delayed(const Duration(seconds: 1));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pool = _pool;
    return Scaffold(
      appBar: AppBar(title: Text(pool?.name ?? '')),
      body: AsyncBody<PoolDetail>(
        value: pool,
        error: _error,
        onRefresh: _load,
        builder: (pool) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _UsageCard(pool: pool),
            _ScrubCard(pool: pool, onAction: (a) => _scrub(pool, a)),
            GroupedCard(
              children: [
                NavRow(
                  icon: Icons.folder_rounded,
                  color: AppPalette.tileBlue,
                  title: l10n.datasetsTitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => DatasetsScreen(
                        session: widget.session,
                        pool: pool.name,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _TopologyCard(pool: pool),
          ],
        ),
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.pool});

  final PoolDetail pool;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VizColors.of(context);
    final percent = (pool.usedFraction * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RingGauge(
                  size: 88,
                  stroke: 9,
                  segments: [(pool.usedFraction, colors.series1)],
                  child: Text('$percent%', style: theme.textTheme.titleLarge),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusPill(
                        label: pool.status,
                        tone: zfsStatusTone(pool.status),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.poolUsage(
                          formatBytes(pool.allocated),
                          formatBytes(pool.size),
                        ),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        l10n.poolFree(formatBytes(pool.free)),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (pool.statusDetail != null && pool.statusDetail!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(pool.statusDetail!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScrubCard extends StatelessWidget {
  const _ScrubCard({required this.pool, required this.onAction});

  final PoolDetail pool;
  final ValueChanged<ScrubAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scan = pool.scan;
    final percent = scan?.percentage.toStringAsFixed(1) ?? '0';
    final scrubbing = scan != null && scan.running && scan.function == 'SCRUB';
    final resilvering =
        scan != null && scan.running && scan.function == 'RESILVER';
    final String text;
    if (scan == null) {
      text = l10n.scrubNever;
    } else if (resilvering) {
      text = l10n.resilverRunning(percent);
    } else if (scrubbing && scan.paused) {
      text = l10n.scrubPaused(percent);
    } else if (scrubbing) {
      text = l10n.scrubRunning(percent);
    } else if (scan.state == 'CANCELED') {
      text = l10n.scrubCanceled;
    } else {
      final end = scan.endTime;
      text = l10n.scrubFinished(
        end == null ? '' : DateFormat.yMMMd(locale).format(end),
        scan.errors,
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.scrubTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(text),
            if (scan != null && scan.running) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: scan.percentage / 100),
            ],
            if (!resilvering) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (!scrubbing || scan.paused)
                    FilledButton.tonalIcon(
                      onPressed: () => onAction(ScrubAction.start),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        scrubbing ? l10n.scrubResume : l10n.scrubStart,
                      ),
                    ),
                  if (scrubbing && !scan.paused)
                    OutlinedButton.icon(
                      onPressed: () => onAction(ScrubAction.pause),
                      icon: const Icon(Icons.pause),
                      label: Text(l10n.scrubPause),
                    ),
                  if (scrubbing)
                    OutlinedButton.icon(
                      onPressed: () => onAction(ScrubAction.stop),
                      icon: const Icon(Icons.stop),
                      label: Text(l10n.scrubStop),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopologyCard extends StatelessWidget {
  const _TopologyCard({required this.pool});

  final PoolDetail pool;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final groupNames = {
      'data': l10n.vdevGroupData,
      'log': l10n.vdevGroupLog,
      'cache': l10n.vdevGroupCache,
      'spare': l10n.vdevGroupSpare,
      'special': l10n.vdevGroupSpecial,
      'dedup': l10n.vdevGroupDedup,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.topologyTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            for (final MapEntry(key: group, value: vdevs)
                in pool.topology.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  groupNames[group] ?? group,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              for (final vdev in vdevs) ..._vdevTiles(context, vdev, 0),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _vdevTiles(BuildContext context, Vdev vdev, int depth) {
    final l10n = AppLocalizations.of(context);
    final (icon, color) = zfsStatusStyle(vdev.status);
    final isDisk = vdev.type == 'DISK';
    return [
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.only(left: 16.0 + depth * 24, right: 16),
        leading: Icon(
          isDisk ? Icons.album_rounded : Icons.account_tree_rounded,
          color: AppPalette.of(context).muted,
        ),
        title: Text(isDisk ? (vdev.disk ?? vdev.name) : vdev.type),
        subtitle: vdev.errors > 0
            ? Text(
                l10n.vdevErrors(
                  vdev.readErrors,
                  vdev.writeErrors,
                  vdev.checksumErrors,
                ),
              )
            : null,
        trailing: StatusLabel(icon: icon, color: color, label: vdev.status),
      ),
      for (final child in vdev.children)
        ..._vdevTiles(context, child, depth + 1),
    ];
  }
}
