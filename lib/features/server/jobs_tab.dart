import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/events.dart';
import '../../core/models/job.dart';
import '../../core/session/truenas_session.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../../shared/connect_dialogs.dart';
import '../../shared/viz_colors.dart';
import '../../shared/dialogs.dart';
import '../../shared/theme.dart';
import '../jobs/hidden_jobs_screen.dart';

/// Recent middleware jobs with live progress.
///
/// Job types the user hid (`hiddenJobMethods`) are left out; a row at the
/// bottom says how many and opens the list to bring them back.
class JobsTab extends ConsumerStatefulWidget {
  const JobsTab({super.key, required this.session});

  final TrueNasSession session;

  @override
  ConsumerState<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends ConsumerState<JobsTab> {
  List<TrueNasJob>? _jobs;
  Object? _error;
  StreamSubscription<CollectionUpdate>? _changes;

  @override
  void initState() {
    super.initState();
    _changes = widget.session.jobChanges().listen(_apply, onError: (_) {});
    _load();
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final jobs = await widget.session.jobs(
        excludeMethods: ref.read(settingsProvider).hiddenJobMethods,
      );
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _apply(CollectionUpdate update) {
    final jobs = _jobs;
    final fields = update.fields;
    if (jobs == null || fields == null) return;
    final id = update.id ?? fields['id'];
    final index = jobs.indexWhere((j) => j.id == id);
    final hidden = ref.read(settingsProvider).hiddenJobMethods;
    setState(() {
      if (index == -1) {
        final job = TrueNasJob.fromJson({'id': id, ...fields});
        if (!hidden.contains(job.method)) jobs.insert(0, job);
      } else {
        jobs[index] = jobs[index].merge(fields);
      }
    });
  }

  Future<void> _abort(TrueNasJob job) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.jobAbortTitle,
      body: job.title,
      confirmLabel: l10n.jobAbort,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await widget.session.abortJob(job.id);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeConnectError(l10n, error))),
      );
    }
  }

  /// Hides (or, from the snackbar's Undo, shows again) the jobs of [method].
  Future<void> _setHidden(String method, {required bool hidden}) => ref
      .read(settingsProvider.notifier)
      .update(
        (s) => s.copyWith(
          hiddenJobMethods: {
            for (final m in s.hiddenJobMethods)
              if (m != method) m,
            if (hidden) method,
          },
        ),
      );

  Future<void> _hide(TrueNasJob job) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await _setHidden(job.method, hidden: true);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.jobTypeHidden(job.method)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => _setHidden(job.method, hidden: false),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hidden = ref.watch(
      settingsProvider.select((s) => s.hiddenJobMethods),
    );
    // Hiding or showing a type changes which jobs the server should list.
    ref.listen(settingsProvider.select((s) => s.hiddenJobMethods), (_, _) {
      _load();
    });
    final all = _jobs;
    // Waiting and running jobs first, each group keeping the server's order.
    final jobs = all == null
        ? null
        : [
            ...all.where((j) => j.state.isActive),
            ...all.where((j) => !j.state.isActive),
          ];
    if (jobs == null) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator.adaptive()
            : Text(describeConnectError(l10n, _error!)),
      );
    }
    return AppRefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (jobs.isEmpty) ...[
            const SizedBox(height: 112),
            Center(
              child: Text(hidden.isEmpty ? l10n.jobsEmpty : l10n.jobsAllHidden),
            ),
            const SizedBox(height: 24),
          ] else
            GroupedCard(
              indent: 72,
              children: [
                for (final job in jobs)
                  _JobTile(job, onAbort: _abort, onHide: _hide),
              ],
            ),
          if (hidden.isNotEmpty) ...[
            const SizedBox(height: 16),
            GroupedCard(
              children: [
                NavRow(
                  icon: Icons.visibility_off_rounded,
                  color: AppPalette.tileSlate,
                  title: l10n.hiddenJobsTitle,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${hidden.length}',
                        style: TextStyle(color: AppPalette.of(context).muted),
                      ),
                      const SizedBox(width: 4),
                      const Chevron(),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const HiddenJobsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile(this.job, {required this.onAbort, required this.onHide});

  final TrueNasJob job;
  final ValueChanged<TrueNasJob> onAbort;
  final ValueChanged<TrueNasJob> onHide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final (icon, color, label) = switch (job.state) {
      JobState.waiting => (
        Icons.schedule,
        theme.colorScheme.onSurfaceVariant,
        l10n.jobStateWaiting,
      ),
      JobState.running => (
        Icons.autorenew,
        theme.colorScheme.primary,
        l10n.jobStateRunning,
      ),
      JobState.success => (
        Icons.check_circle,
        VizColors.good,
        l10n.jobStateSuccess,
      ),
      JobState.failed => (Icons.error, VizColors.critical, l10n.jobStateFailed),
      JobState.aborted => (
        Icons.cancel,
        theme.colorScheme.onSurfaceVariant,
        l10n.jobStateAborted,
      ),
    };
    final started = job.started;
    final meta = [
      label,
      if (started != null) DateFormat.MMMd(locale).add_jm().format(started),
    ].join(' · ');
    final percent = job.percent;
    return ListTile(
      leading: SoftIcon(
        icon,
        statusColors(context, color).$1,
        semanticLabel: label,
      ),
      title: Text(job.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(meta),
          if (job.state == JobState.running) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: percent == null ? null : percent / 100,
            ),
            if (job.progressText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  job.progressText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ],
      ),
      trailing: job.state.isActive && job.abortable || job.method.isNotEmpty
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (job.state.isActive && job.abortable)
                  IconButton(
                    tooltip: l10n.jobAbort,
                    icon: const Icon(Icons.stop_circle_outlined),
                    onPressed: () => onAbort(job),
                  ),
                if (job.method.isNotEmpty)
                  AppPopupMenu<bool>(
                    entries: [menuEntry(true, l10n.jobHideType)],
                    onSelected: (_) => onHide(job),
                  ),
              ],
            )
          : null,
      onTap: job.error == null
          ? null
          : () => showAppDialog<void>(
              context: context,
              builder: (context) => AppDialog(
                title: Text(job.title),
                content: SingleChildScrollView(
                  child: SelectableText(job.error!),
                ),
                actions: [
                  dialogAction(
                    context,
                    label: l10n.close,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
    );
  }
}
