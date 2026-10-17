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

/// How far a bulk run on the server has got: the [action], apps [done] of
/// [total], or null done when it can't be told.
typedef BulkProgress = ({AppBulkAction action, int? done, int total});

/// The apps a bulk action is about to touch. With [showVersions] each shows
/// the version it goes from and to.
class UpdateAllList extends StatelessWidget {
  const UpdateAllList({
    super.key,
    required this.apps,
    this.showVersions = true,
  });

  final List<TrueNasApp> apps;
  final bool showVersions;

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
                if (showVersions) ...[
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
              ],
            ),
          ),
      ],
    );
  }
}

/// The card at the top of the apps list when some apps have updates: how many,
/// and the button that updates them all. While the server runs a bulk action
/// it shows how far it has got; the job carries on if the user leaves.
class UpdateAllCard extends StatelessWidget {
  const UpdateAllCard({
    super.key,
    required this.count,
    required this.onPressed,
    this.progress,
  });

  final int count;
  final VoidCallback onPressed;

  /// Null when nothing is running on the server.
  final BulkProgress? progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final progress = this.progress;
    final done = progress?.done;
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
                  child: Text(
                    progress == null
                        ? l10n.appsUpdatesAvailable(count)
                        : done == null
                        ? l10n.appsBulkRunningNoCount(
                            progress.action.name,
                            progress.total,
                          )
                        : l10n.appsBulkRunning(
                            progress.action.name,
                            done,
                            progress.total,
                          ),
                    style: text.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (progress != null) ...[
              LinearProgressIndicator(
                value: done == null || progress.total == 0
                    ? null
                    : done / progress.total,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(l10n.appsUpdateAllLeave, style: text.bodySmall),
            ] else
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

/// What one button of [AppsBulkBar] does and how many selected apps it applies
/// to.
typedef BulkOption = ({AppBulkAction action, int count});

/// The bar over the tab bar while apps are selected: one button per action
/// that applies to some of them, with how many.
class AppsBulkBar extends StatelessWidget {
  const AppsBulkBar({
    super.key,
    required this.options,
    required this.onPressed,
  });

  final List<BulkOption> options;
  final ValueChanged<AppBulkAction> onPressed;

  static IconData _icon(AppBulkAction action) => switch (action) {
    AppBulkAction.upgrade => Icons.upgrade_rounded,
    AppBulkAction.start => Icons.play_arrow_rounded,
    AppBulkAction.stop => Icons.stop_rounded,
    AppBulkAction.restart => Icons.restart_alt_rounded,
  };

  static String _label(AppLocalizations l10n, AppBulkAction action) =>
      switch (action) {
        AppBulkAction.upgrade => l10n.appsBulkUpdate,
        AppBulkAction.start => l10n.actionStart,
        AppBulkAction.stop => l10n.actionStop,
        AppBulkAction.restart => l10n.actionRestart,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            for (final option in options)
              TextButton.icon(
                onPressed: option.count == 0
                    ? null
                    : () => onPressed(option.action),
                icon: Icon(_icon(option.action)),
                label: Text('${_label(l10n, option.action)} (${option.count})'),
              ),
          ],
        ),
      ),
    );
  }
}
