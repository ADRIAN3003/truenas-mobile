import 'package:flutter/material.dart';

import '../../core/models/storage.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/formatting.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/viz_colors.dart';
import '../protection/protection_screen.dart';
import 'disks_screen.dart';
import 'pool_screen.dart';
import 'storage_helpers.dart';

/// Pools with health and usage, plus the way into disks.
class StorageTab extends StatefulWidget {
  const StorageTab({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<StorageTab> createState() => _StorageTabState();
}

class _StorageTabState extends State<StorageTab> {
  List<PoolDetail>? _pools;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pools = await widget.session.storage.pools();
      if (!mounted) return;
      setState(() {
        _pools = pools;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AsyncBody<List<PoolDetail>>(
      value: _pools,
      error: _error,
      onRefresh: _load,
      builder: (pools) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (pools.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(l10n.poolsEmpty)),
            ),
          for (final pool in pools)
            _PoolCard(
              pool: pool,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PoolScreen(session: widget.session, poolId: pool.id),
                  ),
                );
                _load();
              },
            ),
          const SizedBox(height: 6),
          GroupedCard(
            children: [
              NavRow(
                icon: Icons.album_rounded,
                color: AppPalette.tileSlate,
                title: l10n.disksTitle,
                subtitle: l10n.disksSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DisksScreen(session: widget.session),
                  ),
                ),
              ),
              NavRow(
                icon: Icons.shield_rounded,
                color: AppPalette.tileGreen,
                title: l10n.protectionTitle,
                subtitle: l10n.protectionSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ProtectionScreen(session: widget.session),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PoolCard extends StatelessWidget {
  const _PoolCard({required this.pool, required this.onTap});

  final PoolDetail pool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VizColors.of(context);
    final scan = pool.scan;
    final percent = (pool.usedFraction * 100).round();
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              RingGauge(
                size: 76,
                stroke: 8,
                segments: [(pool.usedFraction, colors.series1)],
                child: Text('$percent%', style: theme.textTheme.titleMedium),
              ),
              const SizedBox(width: 16),
              Expanded(
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
                          tone: zfsStatusTone(pool.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.poolUsage(
                        formatBytes(pool.allocated),
                        formatBytes(pool.size),
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      l10n.poolFree(formatBytes(pool.free)),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (scan != null && scan.running) ...[
                      const SizedBox(height: 8),
                      Text(
                        scan.function == 'RESILVER'
                            ? l10n.resilverRunning(
                                scan.percentage.toStringAsFixed(1),
                              )
                            : l10n.scrubRunning(
                                scan.percentage.toStringAsFixed(1),
                              ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Chevron(),
            ],
          ),
        ),
      ),
    );
  }
}
