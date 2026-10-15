import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/events.dart';
import '../../core/models/job.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/connect_dialogs.dart';
import '../../shared/viz_colors.dart';

/// Recent middleware jobs with live progress.
class JobsTab extends StatefulWidget {
  const JobsTab({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<JobsTab> {
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
      final jobs = await widget.session.jobs();
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
    setState(() {
      if (index == -1) {
        jobs.insert(0, TrueNasJob.fromJson({'id': id, ...fields}));
      } else {
        jobs[index] = jobs[index].merge(fields);
      }
    });
  }

  Future<void> _abort(TrueNasJob job) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.jobAbortTitle),
        content: Text(job.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.jobAbort),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.session.abortJob(job.id);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeConnectError(l10n, error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final jobs = _jobs;
    if (jobs == null) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : Text(describeConnectError(l10n, _error!)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: jobs.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Center(child: Text(l10n.jobsEmpty)),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: jobs.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _JobTile(jobs[index], onAbort: _abort),
            ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile(this.job, {required this.onAbort});

  final TrueNasJob job;
  final ValueChanged<TrueNasJob> onAbort;

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
      leading: Icon(icon, color: color, semanticLabel: label),
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
      trailing: job.state.isActive && job.abortable
          ? IconButton(
              tooltip: l10n.jobAbort,
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: () => onAbort(job),
            )
          : null,
      onTap: job.error == null
          ? null
          : () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(job.title),
                content: SingleChildScrollView(
                  child: SelectableText(job.error!),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.close),
                  ),
                ],
              ),
            ),
    );
  }
}
