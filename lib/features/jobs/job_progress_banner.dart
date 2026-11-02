import 'package:flutter/material.dart';

import '../../core/jobs/job_tracker.dart';
import '../../core/jobs/tracked_job.dart';
import '../../core/models/job.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/viz_colors.dart';
import 'job_texts.dart';

/// A card over the bottom of the server screen with the scrubs,
/// replications and updates that run, one at a time: swipe sideways for the
/// next one. Gone when there are none, and hidden by its close button until
/// another job starts.
class JobProgressBanner extends StatefulWidget {
  const JobProgressBanner({
    super.key,
    required this.tracker,
    required this.onOpen,
  });

  final JobTracker tracker;

  /// Opens the full list of jobs.
  final VoidCallback onOpen;

  @override
  State<JobProgressBanner> createState() => _JobProgressBannerState();
}

class _JobProgressBannerState extends State<JobProgressBanner> {
  /// Jobs the user hid. A job that starts later is not among them.
  final _dismissed = <int>{};
  final _controller = PageController();

  /// The job the user is looking at, so a list that changes under them (a job
  /// ends, another starts) does not move them to a different one.
  int? _viewing;
  int _lastIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Running jobs first, in start order, then the ones that just finished.
  List<TrackedJob> _visible(JobsSnapshot data) {
    final open = [
      for (final job in data.jobs)
        if (!_dismissed.contains(job.id)) job,
    ];
    return [
      ...open.where((t) => t.job.state.isActive),
      ...open.where((t) => !t.job.state.isActive),
    ];
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<JobsSnapshot>(
    stream: widget.tracker.snapshots,
    initialData: widget.tracker.snapshot,
    builder: (context, snapshot) {
      final data = snapshot.requireData;
      final visible = _visible(data);
      if (visible.isEmpty) return const SizedBox.shrink();
      final l10n = AppLocalizations.of(context);
      final theme = Theme.of(context);
      var index = visible.indexWhere((t) => t.id == _viewing);
      if (index < 0) index = _lastIndex.clamp(0, visible.length - 1);
      _lastIndex = index;
      _viewing = visible[index].id;
      // The pages moved under the user's finger (a job ended before the one
      // they look at): bring the view back to their job.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        final page = _controller.page;
        if (page != null && page == page.roundToDouble() && page != index) {
          _controller.jumpToPage(index);
        }
      });
      // A page needs a height of its own; this fits a title, a detail line
      // and a progress bar at the user's text size.
      final pageHeight = MediaQuery.textScalerOf(context).scale(36) + 14;
      return Semantics(
        container: true,
        child: Material(
          color: theme.colorScheme.surfaceContainerHigh,
          elevation: 4,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: pageHeight,
                            child: PageView.builder(
                              key: const ValueKey('job-pages'),
                              controller: _controller,
                              itemCount: visible.length,
                              onPageChanged: (i) {
                                _lastIndex = i;
                                _viewing = visible[i].id;
                                setState(() {});
                              },
                              itemBuilder: (_, i) => Align(
                                alignment: Alignment.centerLeft,
                                child: _BannerRow(
                                  visible[i],
                                  connected: data.connected,
                                ),
                              ),
                            ),
                          ),
                          if (visible.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _PageDots(
                                count: visible.length,
                                index: index,
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
                  IconButton(
                    tooltip: l10n.jobsDismiss,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => setState(
                      () => _dismissed.addAll(visible.map((job) => job.id)),
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

/// One dot per job, the one on show longer and in the accent colour. A long
/// list shows a count instead of a row of dots.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  static const _maxDots = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (count > _maxDots) {
      return Text(
        '${index + 1} / $count',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall,
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: i == index
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }
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
