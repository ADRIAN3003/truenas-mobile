import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/protection.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/viz_colors.dart';
import '../../shared/widgets.dart';
import '../sharing/sharing_widgets.dart';
import '../storage/storage_helpers.dart';
import 'task_editors.dart';
import '../../shared/dialogs.dart';

typedef _Tasks = Map<ProtectionKind, List<ProtectionTask>>;

/// Periodic snapshots, replication, cloud sync, cloud backup and rsync
/// tasks: their last result, enable/disable, run now, and adding or
/// editing snapshot, replication and cloud sync tasks.
class ProtectionScreen extends StatefulWidget {
  const ProtectionScreen({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<ProtectionScreen> createState() => _ProtectionScreenState();
}

class _ProtectionScreenState extends State<ProtectionScreen>
    with LoadState<ProtectionScreen, _Tasks> {
  TrueNasSession get _session => widget.session;

  @override
  Future<_Tasks> fetch() => _session.protection.allTasks();

  Future<void> _setEnabled(ProtectionTask task, bool enabled) async {
    final l10n = AppLocalizations.of(context);
    final ok = await runWithFeedback(
      context,
      () => _session.protection.setEnabled(task, enabled),
      success: enabled
          ? l10n.taskEnabledMessage(task.name)
          : l10n.taskDisabledMessage(task.name),
    );
    if (ok) await load();
  }

  Future<void> _action(ProtectionTask task, String action) async {
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case 'run':
        await runWithFeedback(
          context,
          () => _session.protection.runNow(task),
          success: l10n.taskStarted(task.name),
        );
      case 'stop':
        await runWithFeedback(
          context,
          () => _session.protection.abort(task),
          success: l10n.taskStopped(task.name),
        );
      case 'edit':
        await _edit(task.kind, task);
        return;
      case 'delete':
        final confirmed = await confirmAction(
          context,
          title: l10n.taskDeleteTitle(task.name),
          body: task.kind == ProtectionKind.snapshot
              ? l10n.taskDeleteBody
              : l10n.taskDeleteBodyCopies,
          confirmLabel: l10n.delete,
          cancelLabel: l10n.cancel,
          destructive: true,
        );
        if (!confirmed || !mounted) return;
        await runWithFeedback(
          context,
          () => _session.protection.delete(task),
          success: l10n.taskDeleted,
        );
    }
    if (mounted) await load();
  }

  /// Opens the editor for a new task of [kind], or for [task].
  Future<void> _edit(ProtectionKind kind, [ProtectionTask? task]) async {
    if (kind == ProtectionKind.snapshot) return _createSnapshotTask();
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => switch (kind) {
          ProtectionKind.replication => ReplicationEditor(
            session: _session,
            task: task,
          ),
          ProtectionKind.cloudSync => CloudSyncEditor(
            session: _session,
            task: task,
          ),
          ProtectionKind.cloudBackup => CloudBackupEditor(
            session: _session,
            task: task,
          ),
          ProtectionKind.rsync => RsyncEditor(session: _session, task: task),
          ProtectionKind.snapshot => throw StateError('dialog'),
        },
      ),
    );
    if (saved == true && mounted) await load();
  }

  Future<void> _add(List<ProtectionKind> kinds) async {
    final l10n = AppLocalizations.of(context);
    final kind = await showAppSheet<ProtectionKind>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kind in kinds)
              ListTile(
                leading: IconTile(kindIcon(kind), kindColor(kind)),
                title: Text(kindTitle(l10n, kind)),
                onTap: () => Navigator.pop(context, kind),
              ),
          ],
        ),
      ),
    );
    if (kind != null && mounted) await _edit(kind);
  }

  Future<void> _createSnapshotTask() async {
    final l10n = AppLocalizations.of(context);
    final datasets = await localDatasets(_session);
    if (!mounted) return;
    final request = await showAppDialog<_NewSnapshotTask>(
      context: context,
      builder: (_) => _NewSnapshotTaskDialog(datasets: datasets),
    );
    if (request == null || !mounted) return;
    final ok = await runWithFeedback(
      context,
      () => _session.protection.createSnapshotTask(
        dataset: request.dataset,
        recursive: request.recursive,
        lifetimeValue: request.keep,
        lifetimeUnit: request.unit,
        schedule: request.schedule,
      ),
      success: l10n.snapshotTaskCreated(request.dataset),
    );
    if (ok) await load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final creatable = [
      for (final kind in data?.keys ?? const <ProtectionKind>[]) kind,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.protectionTitle)),
      floatingActionButton: creatable.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _add(creatable),
              icon: const Icon(Icons.add),
              label: Text(l10n.protectionAdd),
            )
          : null,
      body: AsyncBody<_Tasks>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (tasks) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
          children: [
            for (final MapEntry(key: kind, value: list) in tasks.entries)
              ...groupedSection(
                kindTitle(l10n, kind),
                empty: l10n.protectionEmpty,
                indent: 72,
                [
                  for (final task in list)
                    _TaskTile(
                      task: task,
                      onToggle: (v) => _setEnabled(task, v),
                      onAction: (a) => _action(task, a),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String kindTitle(AppLocalizations l10n, ProtectionKind kind) => switch (kind) {
  ProtectionKind.snapshot => l10n.protectionSnapshots,
  ProtectionKind.replication => l10n.protectionReplication,
  ProtectionKind.cloudSync => l10n.protectionCloudSync,
  ProtectionKind.cloudBackup => l10n.protectionCloudBackup,
  ProtectionKind.rsync => l10n.protectionRsync,
};

IconData kindIcon(ProtectionKind kind) => switch (kind) {
  ProtectionKind.snapshot => Icons.photo_camera_rounded,
  ProtectionKind.replication => Icons.compare_arrows_rounded,
  ProtectionKind.cloudSync => Icons.cloud_sync_rounded,
  ProtectionKind.cloudBackup => Icons.backup_rounded,
  ProtectionKind.rsync => Icons.sync_alt_rounded,
};

Color kindColor(ProtectionKind kind) => switch (kind) {
  ProtectionKind.snapshot => AppPalette.tileTeal,
  ProtectionKind.replication => AppPalette.tilePurple,
  ProtectionKind.cloudSync => AppPalette.tileBlue,
  ProtectionKind.cloudBackup => AppPalette.tileOrange,
  ProtectionKind.rsync => AppPalette.tileGreen,
};

String keepFor(AppLocalizations l10n, int count, LifetimeUnit unit) =>
    switch (unit) {
      LifetimeUnit.hour => l10n.keepHours(count),
      LifetimeUnit.day => l10n.keepDays(count),
      LifetimeUnit.week => l10n.keepWeeks(count),
      LifetimeUnit.month => l10n.keepMonths(count),
      LifetimeUnit.year => l10n.keepYears(count),
    };

String scheduleLabel(AppLocalizations l10n, Object? schedule) =>
    switch (schedule) {
      SnapshotSchedule.hourly => l10n.scheduleHourly,
      SnapshotSchedule.daily => l10n.scheduleDaily,
      SnapshotSchedule.weekly => l10n.scheduleWeekly,
      final String cron => l10n.scheduleCustom(cron),
      _ => '',
    };

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onAction,
  });

  final ProtectionTask task;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final muted = theme.colorScheme.onSurfaceVariant;
    final detail = task.kind == ProtectionKind.snapshot
        ? [
            scheduleLabel(l10n, task.schedule),
            if (task.lifetimeValue case final count?)
              if (task.lifetimeUnit case final unit?)
                keepFor(l10n, count, unit),
            if (task.recursive) l10n.snapshotTaskRecursiveLabel,
          ].where((s) => s.isNotEmpty).join(' · ')
        : task.detail;
    final running = task.status == TaskStatus.running;
    final progress = task.progress;
    final (icon, color, label) = switch (task.status) {
      TaskStatus.success => (
        Icons.check_circle,
        VizColors.good,
        l10n.taskSuccess,
      ),
      TaskStatus.failed => (Icons.error, VizColors.critical, l10n.taskFailed),
      TaskStatus.running => (
        Icons.sync,
        theme.colorScheme.primary,
        progress == null
            ? l10n.taskRunning
            : l10n.taskRunningPercent(progress.round()),
      ),
      TaskStatus.waiting => (
        Icons.schedule,
        VizColors.warning,
        l10n.taskWaiting,
      ),
      TaskStatus.held => (Icons.pause_circle, VizColors.warning, l10n.taskHeld),
      TaskStatus.never => (Icons.remove_circle_outline, muted, l10n.taskNever),
    };
    final lastRun = task.lastRun;
    return ListTile(
      leading: IconTile(kindIcon(task.kind), kindColor(task.kind), size: 40),
      title: Text(task.name),
      onTap: task.kind != ProtectionKind.snapshot
          ? () => onAction('edit')
          : null,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.isNotEmpty)
            Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 12,
              children: [
                StatusLabel(icon: icon, color: color, label: label),
                if (lastRun != null && !running)
                  Text(
                    l10n.taskLastRun(
                      DateFormat.MMMd(locale)
                          .add_jm()
                          .format(lastRun.toLocal()),
                    ),
                  ),
              ],
            ),
          ),
          if (task.error case final error?
              when task.status == TaskStatus.failed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: l10n.taskEnabled,
            child: AppSwitch(value: task.enabled, onChanged: onToggle),
          ),
          AppPopupMenu<String>(
            onSelected: onAction,
            entries: [
              if (running && task.kind.abortable)
                menuEntry('stop', l10n.taskStop)
              else if (!running)
                menuEntry('run', l10n.taskRunNow),
              if (task.kind != ProtectionKind.snapshot)
                menuEntry('edit', l10n.edit),
              menuEntry('delete', l10n.delete, destructive: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewSnapshotTask {
  const _NewSnapshotTask(
    this.dataset,
    this.recursive,
    this.schedule,
    this.keep,
    this.unit,
  );

  final String dataset;
  final bool recursive;
  final SnapshotSchedule schedule;
  final int keep;
  final LifetimeUnit unit;
}

class _NewSnapshotTaskDialog extends StatefulWidget {
  const _NewSnapshotTaskDialog({required this.datasets});

  final List<String> datasets;

  @override
  State<_NewSnapshotTaskDialog> createState() => _NewSnapshotTaskDialogState();
}

class _NewSnapshotTaskDialogState extends State<_NewSnapshotTaskDialog> {
  late String? _dataset = widget.datasets.firstOrNull;
  bool _recursive = false;
  SnapshotSchedule _schedule = SnapshotSchedule.daily;
  final _keep = TextEditingController(text: '2');
  LifetimeUnit _unit = LifetimeUnit.week;

  @override
  void dispose() {
    _keep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dataset = _dataset;
    final keep = int.tryParse(_keep.text.trim());
    return AppDialog(
      title: Text(l10n.snapshotTaskCreate),
      content: dataset == null
          ? Text(l10n.shareNoDatasets)
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: dataset,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.snapshotTaskDataset,
                    ),
                    items: [
                      for (final d in widget.datasets)
                        DropdownMenuItem(
                          value: d,
                          child: Text(d, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (d) => setState(() => _dataset = d),
                  ),
                  AppSwitchTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.snapshotTaskRecursive),
                    value: _recursive,
                    onChanged: (v) => setState(() => _recursive = v),
                  ),
                  DropdownButtonFormField<SnapshotSchedule>(
                    initialValue: _schedule,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.snapshotTaskSchedule,
                    ),
                    items: [
                      for (final s in SnapshotSchedule.values)
                        DropdownMenuItem(
                          value: s,
                          child: Text(scheduleLabel(l10n, s)),
                        ),
                    ],
                    onChanged: (s) => setState(() => _schedule = s!),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 72,
                        child: TextField(
                          controller: _keep,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.snapshotTaskKeepFor,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<LifetimeUnit>(
                          initialValue: _unit,
                          isExpanded: true,
                          items: [
                            for (final u in LifetimeUnit.values)
                              DropdownMenuItem(
                                value: u,
                                child: Text(switch (u) {
                                  LifetimeUnit.hour => l10n.unitHours,
                                  LifetimeUnit.day => l10n.unitDays,
                                  LifetimeUnit.week => l10n.unitWeeks,
                                  LifetimeUnit.month => l10n.unitMonths,
                                  LifetimeUnit.year => l10n.unitYears,
                                }),
                              ),
                          ],
                          onChanged: (u) => setState(() => _unit = u!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: dataset == null || keep == null || keep < 1
              ? null
              : () => Navigator.pop(
                  context,
                  _NewSnapshotTask(dataset, _recursive, _schedule, keep, _unit),
                ),
          child: Text(l10n.create),
        ),
      ],
    );
  }
}
