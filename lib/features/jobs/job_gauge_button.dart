import 'package:flutter/material.dart';

import '../../core/jobs/job_tracker.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/haptics.dart';

/// A small ring in the app bar that fills as the running jobs progress, with
/// the number of jobs in it when there are several. Spins while no job says
/// how far along it is. Gone when nothing runs; tapping it opens the jobs.
class JobGaugeButton extends StatelessWidget {
  const JobGaugeButton({
    super.key,
    required this.tracker,
    required this.onOpen,
  });

  final JobTracker tracker;
  final VoidCallback onOpen;

  /// The mean progress of the running jobs, 0 to 1, or null when none of
  /// them reports a percent.
  static double? progressOf(JobsSnapshot snapshot) {
    final percents = [
      for (final t in snapshot.jobs)
        if (t.job.state.isActive && t.job.percent != null) t.job.percent!,
    ];
    if (percents.isEmpty) return null;
    final mean = percents.reduce((a, b) => a + b) / percents.length;
    return (mean / 100).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<JobsSnapshot>(
    stream: tracker.snapshots,
    initialData: tracker.snapshot,
    builder: (context, snapshot) {
      final data = snapshot.requireData;
      final count = data.jobs.where((t) => t.job.state.isActive).length;
      final theme = Theme.of(context);
      final progress = progressOf(data);
      final color = data.connected
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: count == 0
            ? const SizedBox.shrink(key: ValueKey('none'))
            : IconButton(
                key: const ValueKey('gauge'),
                tooltip: AppLocalizations.of(context).jobsRunningCount(count),
                onPressed: () {
                  Haptics.selection();
                  onOpen();
                },
                icon: SizedBox.square(
                  dimension: 26,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (progress == null)
                        CircularProgressIndicator(
                          strokeWidth: 3,
                          strokeCap: StrokeCap.round,
                          color: color,
                          backgroundColor: color.withValues(alpha: 0.2),
                        )
                      else
                        // Eases between values instead of jumping.
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: progress),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) =>
                              CircularProgressIndicator(
                                value: value,
                                strokeWidth: 3,
                                strokeCap: StrokeCap.round,
                                color: color,
                                backgroundColor: color.withValues(alpha: 0.2),
                              ),
                        ),
                      if (count > 1)
                        Text(
                          '$count',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        Icon(Icons.speed_rounded, size: 13, color: color),
                    ],
                  ),
                ),
              ),
      );
    },
  );
}
