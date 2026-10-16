import 'package:flutter/material.dart';

import '../../core/models/workloads.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';

/// The apps that have a newer version, in the order "Update all" updates them.
List<TrueNasApp> appsWithUpdates(Iterable<TrueNasApp> apps) => [
  for (final app in apps)
    if (app.upgradeAvailable) app,
];

/// How far "Update all" has got.
typedef UpdateAllProgress = ({int done, int total, String name});

/// What "Update all" is about to do: every app with the version it goes from
/// and to.
class UpdateAllList extends StatelessWidget {
  const UpdateAllList({super.key, required this.apps});

  final List<TrueNasApp> apps;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final app in apps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    app.title ?? app.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    [
                      app.chartVersion ?? app.version,
                      if (app.latestVersion != null) app.latestVersion!,
                    ].join(' → '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The card at the top of the apps list when some apps have updates: how many,
/// and the button that updates them all. While that runs it shows which app is
/// being updated.
class UpdateAllCard extends StatelessWidget {
  const UpdateAllCard({
    super.key,
    required this.count,
    required this.onPressed,
    this.progress,
  });

  final int count;
  final VoidCallback onPressed;

  /// Null when nothing is being updated.
  final UpdateAllProgress? progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progress = this.progress;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconTile(Icons.upgrade_rounded, AppPalette.tileBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appsUpdatesAvailable(count),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (progress != null)
                        Text(
                          l10n.appsUpdateAllProgress(
                            progress.name,
                            progress.done + 1,
                            progress.total,
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (progress != null)
              LinearProgressIndicator(
                value: progress.done / progress.total,
                borderRadius: BorderRadius.circular(4),
              )
            else
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.upgrade_rounded),
                label: Text(l10n.appsUpdateAll),
              ),
          ],
        ),
      ),
    );
  }
}
