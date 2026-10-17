import 'package:flutter/material.dart';

import '../../core/jobs/job_tracker.dart';
import '../../core/jobs/tracked_job.dart';
import '../../core/models/job.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/viz_colors.dart';
import 'job_texts.dart';

/// How many jobs the banner lists before it says "+N more".
const bannerLimit = 3;

/// A card over the bottom of the server screen with the scrubs,
/// replications and updates that run. Gone when there are none.
class JobProgressBanner extends StatelessWidget {
  const JobProgressBanner({
    super.key,
    required this.tracker,
    required this.onOpen,
  });

  final JobTracker tracker;

  /// Opens the full list of jobs.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => StreamBuilder<JobsSnapshot>(
    stream: tracker.snapshots,
    initialData: tracker.snapshot,
    builder: (context, snapshot) {
      final data = snapshot.requireData;
      if (data.jobs.isEmpty) return const SizedBox.shrink();
      final l10n = AppLocalizations.of(context);
      final theme = Theme.of(context);
      final shown = data.jobs.take(bannerLimit).toList();
      final more = data.jobs.length - shown.length;
      return Semantics(
        container: true,
        child: Material(
          color: theme.colorScheme.surfaceContainerHigh,
          elevation: 4,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _BannerRow(shown[i], connected: data.connected),
                  ],
                  if (more > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.jobsMoreCount(more),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  if (!data.connected && data.hasActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.jobsConnectionLost,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _BannerRow extends StatelessWidget {
  const _BannerRow(this.tracked, {required this.connected});

  final TrackedJob tracked;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final job = tracked.job;
    final (icon, color) = switch (job.state) {
      JobState.success => (Icons.check_circle, VizColors.good),
      JobState.failed => (Icons.error, VizColors.critical),
      JobState.aborted => (Icons.cancel, theme.colorScheme.onSurfaceVariant),
      _ => (_kindIcon(tracked.kind), theme.colorScheme.primary),
    };
    final percent = job.percent;
    final title = tracked.target == null
        ? l10n.jobKindName(tracked.kind)
        : '${l10n.jobKindName(tracked.kind)} · ${tracked.target}';
    final detail = switch (job.state) {
      JobState.failed when job.error?.isNotEmpty == true =>
        job.error!.trim().split('\n').first,
      JobState.running => job.progressText,
      JobState.waiting => l10n.jobStateWaiting,
      JobState.success => l10n.jobStateSuccess,
      JobState.aborted => l10n.jobStateAborted,
      _ => '',
    };
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              if (detail.isNotEmpty)
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              if (job.state.isActive) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: job.state == JobState.running && percent != null
                      ? (percent / 100).clamp(0.0, 1.0)
                      : null,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ],
          ),
        ),
        if (job.state == JobState.running && percent != null) ...[
          const SizedBox(width: 12),
          Text(
            '${percent.round()}%',
            style: theme.textTheme.titleSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }

  static IconData _kindIcon(JobKind kind) => switch (kind) {
    JobKind.scrub => Icons.cleaning_services_rounded,
    JobKind.replication => Icons.sync_alt_rounded,
    JobKind.appUpdate => Icons.system_update_alt_rounded,
    JobKind.cloudSync || JobKind.cloudBackup => Icons.cloud_sync_rounded,
    JobKind.rsync => Icons.sync_rounded,
    JobKind.systemUpdate => Icons.system_update_rounded,
  };
}
