import 'package:flutter/material.dart';

import '../../core/models/protection.dart';
import '../../core/models/protection_drafts.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../sharing/sharing_widgets.dart';
import '../storage/storage_helpers.dart';
import 'protection_screen.dart';

/// Every dataset on the server, e.g. `tank/media`.
Future<List<String>> localDatasets(TrueNasSession session) async {
  final names = <String>[];
  for (final pool in await session.storage.pools()) {
    for (final d in await session.storage.datasets(pool.name)) {
      names.add(d.id);
    }
  }
  return names;
}

Future<String?> _pickDataset(BuildContext context, List<String> datasets) =>
    showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context).pickDataset),
        children: [
          for (final d in datasets)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, d),
              child: Text(d),
            ),
        ],
      ),
    );

String? _required(AppLocalizations l10n, String? value) =>
    (value ?? '').trim().isEmpty ? l10n.validationRequired : null;

/// Schedule choices: the presets, plus [current] when it is cron text the
/// app keeps as it is, plus [extra] (a null entry) when given.
List<DropdownMenuItem<Object?>> _scheduleItems(
  AppLocalizations l10n,
  Object? current, {
  String? extra,
}) => [
  if (extra != null) DropdownMenuItem(value: null, child: Text(extra)),
  for (final s in SnapshotSchedule.values)
    DropdownMenuItem(value: s, child: Text(scheduleLabel(l10n, s))),
  if (current is String)
    DropdownMenuItem(value: current, child: Text(scheduleLabel(l10n, current))),
];

/// Save button and loading state shared by both editors.
mixin _EditorState<W extends StatefulWidget, T> on LoadState<W, T> {
  final formKey = GlobalKey<FormState>();
  bool saving = false;

  Future<void> save(Future<void> Function() action, String name) async {
    if (!formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() => saving = true);
    final ok = await runWithFeedback(
      context,
      action,
      success: l10n.taskSaved(name),
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (ok) Navigator.pop(context, true);
  }

  Widget scaffold({
    required String title,
    required VoidCallback onSave,
    required List<Widget> Function(T options) fields,
  }) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: data == null || saving ? null : onSave,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: AsyncBody<T>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (options) => Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              for (final field in fields(options))
                Center(
                  child: ConstrainedBox(
                    // Keeps the form readable on tablets.
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: field,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _ReplicationOptions = ({
  List<String> datasets,
  List<PickOption> ssh,
  List<PickOption> snapshotTasks,
});

/// Creates a replication task, or edits [task]. Pops `true` once saved.
class ReplicationEditor extends StatefulWidget {
  const ReplicationEditor({super.key, required this.session, this.task});

  final TrueNasSession session;
  final ProtectionTask? task;

  @override
  State<ReplicationEditor> createState() => _ReplicationEditorState();
}

class _ReplicationEditorState extends State<ReplicationEditor>
    with
        LoadState<ReplicationEditor, _ReplicationOptions>,
        _EditorState<ReplicationEditor, _ReplicationOptions> {
  late final _draft = widget.task == null
      ? ReplicationDraft()
      : ReplicationDraft.fromJson(widget.task!.raw);
  late final _initialTransport = _draft.transport;
  late final _name = TextEditingController(text: _draft.name);
  late final _sources = TextEditingController(
    text: _draft.sourceDatasets.join(', '),
  );
  late final _target = TextEditingController(text: _draft.targetDataset);
  late final _schema = TextEditingController(text: _draft.namingSchema);
  late final _keep = TextEditingController(text: '${_draft.lifetimeValue}');

  @override
  Future<_ReplicationOptions> fetch() async {
    final protection = widget.session.protection;
    final (datasets, ssh, tasks) = await (
      localDatasets(widget.session),
      protection.sshCredentials(),
      protection.tasks(ProtectionKind.snapshot),
    ).wait;
    return (
      datasets: datasets,
      ssh: ssh,
      snapshotTasks: [
        for (final t in tasks)
          PickOption(
            t.id,
            t.name,
            (t.raw['naming_schema'] ?? defaultNamingSchema).toString(),
          ),
      ],
    );
  }

  @override
  void dispose() {
    for (final c in [_name, _sources, _target, _schema, _keep]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    _draft
      ..name = _name.text.trim()
      ..sourceDatasets = [
        for (final s in _sources.text.split(','))
          if (s.trim().isNotEmpty) s.trim(),
      ]
      ..targetDataset = _target.text.trim()
      ..namingSchema = _schema.text.trim()
      ..lifetimeValue = int.tryParse(_keep.text.trim()) ?? 1;
    save(
      () => widget.session.protection.saveReplication(
        _draft,
        id: widget.task?.id,
      ),
      _draft.name,
    );
  }

  Future<void> _pickInto(
    TextEditingController controller,
    List<String> datasets, {
    bool append = false,
  }) async {
    final picked = await _pickDataset(context, datasets);
    if (picked == null) return;
    final current = controller.text.trim();
    controller.text = append && current.isNotEmpty
        ? '$current, $picked'
        : picked;
  }

  void _toggleSnapshotTask(int id, bool selected) => setState(() {
    final wasBound = _draft.bound;
    _draft.snapshotTasks = selected
        ? [..._draft.snapshotTasks, id]
        : [..._draft.snapshotTasks.where((t) => t != id)];
    // New tasks follow their snapshots unless a schedule is chosen.
    if (!wasBound && _draft.bound && widget.task == null) {
      _draft.schedule = null;
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final d = _draft;
    if (!d.bound && d.schedule == null) d.schedule = SnapshotSchedule.daily;
    final regex = d.nameRegex;
    return scaffold(
      title: widget.task == null ? l10n.replicationNew : l10n.replicationEdit,
      onSave: _save,
      fields: (options) => [
        TextFormField(
          controller: _name,
          decoration: InputDecoration(labelText: l10n.taskNameLabel),
          validator: (v) => _required(l10n, v),
        ),
        DropdownButtonFormField<bool>(
          initialValue: d.push,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.directionLabel),
          items: [
            DropdownMenuItem(value: true, child: Text(l10n.replicationPush)),
            DropdownMenuItem(value: false, child: Text(l10n.replicationPull)),
          ],
          onChanged: (v) => setState(() => d.push = v!),
        ),
        DropdownButtonFormField<String>(
          initialValue: d.transport,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.replicationTransport),
          items: [
            DropdownMenuItem(value: 'LOCAL', child: Text(l10n.transportLocal)),
            DropdownMenuItem(value: 'SSH', child: Text(l10n.transportSsh)),
            if (_initialTransport == 'SSH+NETCAT')
              DropdownMenuItem(
                value: 'SSH+NETCAT',
                child: Text(l10n.transportNetcat),
              ),
          ],
          onChanged: (v) => setState(() => d.transport = v!),
        ),
        if (!d.local)
          if (options.ssh.isEmpty)
            Text(
              l10n.replicationNoSshConnections,
              style: TextStyle(color: theme.colorScheme.error),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: options.ssh.any((o) => o.id == d.sshCredentials)
                  ? d.sshCredentials
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.replicationSshConnection,
              ),
              items: [
                for (final o in options.ssh)
                  DropdownMenuItem(value: o.id, child: Text(o.name)),
              ],
              validator: (v) => v == null ? l10n.validationRequired : null,
              onChanged: (v) => setState(() => d.sshCredentials = v),
            ),
        TextFormField(
          controller: _sources,
          decoration: InputDecoration(
            labelText: l10n.replicationSources,
            helperText: l10n.replicationSourcesHint,
            suffixIcon: d.push
                ? IconButton(
                    tooltip: l10n.pickDataset,
                    icon: const Icon(Icons.list),
                    onPressed: () =>
                        _pickInto(_sources, options.datasets, append: true),
                  )
                : null,
          ),
          validator: (v) => _required(l10n, v),
        ),
        TextFormField(
          controller: _target,
          decoration: InputDecoration(
            labelText: l10n.replicationTarget,
            suffixIcon: !d.push || d.local
                ? IconButton(
                    tooltip: l10n.pickDataset,
                    icon: const Icon(Icons.list),
                    onPressed: () => _pickInto(_target, options.datasets),
                  )
                : null,
          ),
          validator: (v) => _required(l10n, v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.snapshotTaskRecursive),
          value: d.recursive,
          onChanged: (v) => setState(() => d.recursive = v),
        ),
        if (regex != null)
          Text(l10n.replicationNameRegex(regex))
        else ...[
          if (d.push) ...[
            Text(
              l10n.replicationSnapshotTasks,
              style: theme.textTheme.titleSmall,
            ),
            if (options.snapshotTasks.isEmpty)
              Text(l10n.replicationNoSnapshotTasks)
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in options.snapshotTasks)
                    FilterChip(
                      label: Text(t.name),
                      tooltip: t.detail,
                      selected: d.snapshotTasks.contains(t.id),
                      onSelected: (v) => _toggleSnapshotTask(t.id, v),
                    ),
                ],
              ),
          ],
          if (!d.bound)
            TextFormField(
              controller: _schema,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.replicationNamingSchema,
                helperText: l10n.replicationNamingSchemaHint,
              ),
              validator: (v) => _required(l10n, v),
            ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.replicationAuto),
          value: d.auto,
          onChanged: (v) => setState(() => d.auto = v),
        ),
        if (d.auto)
          DropdownButtonFormField<Object?>(
            key: ValueKey(d.bound),
            initialValue: d.schedule,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.snapshotTaskSchedule),
            items: _scheduleItems(
              l10n,
              d.schedule,
              extra: d.bound ? l10n.replicationAfterSnapshots : null,
            ),
            onChanged: (v) => setState(() => d.schedule = v),
          ),
        DropdownButtonFormField<RetentionPolicy>(
          initialValue: d.retention,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.replicationRetention),
          items: [
            for (final p in RetentionPolicy.values)
              DropdownMenuItem(
                value: p,
                child: Text(switch (p) {
                  RetentionPolicy.source => l10n.retentionSource,
                  RetentionPolicy.custom => l10n.retentionCustom,
                  RetentionPolicy.none => l10n.retentionNone,
                }),
              ),
          ],
          onChanged: (v) => setState(() => d.retention = v!),
        ),
        if (d.retention == RetentionPolicy.custom)
          LifetimeFields(
            keep: _keep,
            unit: d.lifetimeUnit,
            onUnit: (u) => setState(() => d.lifetimeUnit = u),
          ),
      ],
    );
  }
}

/// "Keep for" count and unit, side by side.
class LifetimeFields extends StatelessWidget {
  const LifetimeFields({
    super.key,
    required this.keep,
    required this.unit,
    required this.onUnit,
    this.onChanged,
  });

  final TextEditingController keep;
  final LifetimeUnit unit;
  final ValueChanged<LifetimeUnit> onUnit;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: TextFormField(
            controller: keep,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.snapshotTaskKeepFor),
            validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) < 1
                ? l10n.explorerInvalidNumber
                : null,
            onChanged: (_) => onChanged?.call(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<LifetimeUnit>(
            initialValue: unit,
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
            onChanged: (u) => onUnit(u!),
          ),
        ),
      ],
    );
  }
}

typedef _CloudOptions = ({List<String> datasets, List<PickOption> credentials});

/// Creates a cloud sync task, or edits [task]. Pops `true` once saved.
class CloudSyncEditor extends StatefulWidget {
  const CloudSyncEditor({super.key, required this.session, this.task});

  final TrueNasSession session;
  final ProtectionTask? task;

  @override
  State<CloudSyncEditor> createState() => _CloudSyncEditorState();
}

class _CloudSyncEditorState extends State<CloudSyncEditor>
    with
        LoadState<CloudSyncEditor, _CloudOptions>,
        _EditorState<CloudSyncEditor, _CloudOptions> {
  late final _draft = widget.task == null
      ? CloudSyncDraft()
      : CloudSyncDraft.fromJson(widget.task!.raw);
  late final _description = TextEditingController(text: _draft.description);
  late final _bucket = TextEditingController(text: _draft.bucket);
  late final _folder = TextEditingController(text: _draft.folder);
  late final _path = TextEditingController(text: _draft.path);

  @override
  Future<_CloudOptions> fetch() async {
    final (datasets, credentials) = await (
      localDatasets(widget.session),
      widget.session.protection.cloudCredentials(),
    ).wait;
    return (datasets: datasets, credentials: credentials);
  }

  @override
  void dispose() {
    for (final c in [_description, _bucket, _folder, _path]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    _draft
      ..description = _description.text.trim()
      ..bucket = _bucket.text.trim()
      ..folder = _folder.text.trim()
      ..path = _path.text.trim();
    save(
      () =>
          widget.session.protection.saveCloudSync(_draft, id: widget.task?.id),
      _draft.description.isEmpty ? _draft.path : _draft.description,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final d = _draft;
    return scaffold(
      title: widget.task == null ? l10n.cloudSyncNew : l10n.cloudSyncEdit,
      onSave: _save,
      fields: (options) => [
        TextFormField(
          controller: _description,
          decoration: InputDecoration(labelText: l10n.cloudSyncDescription),
        ),
        if (options.credentials.isEmpty)
          Text(
            l10n.cloudSyncNoCredentials,
            style: TextStyle(color: theme.colorScheme.error),
          )
        else
          DropdownButtonFormField<int>(
            initialValue: options.credentials.any((o) => o.id == d.credentials)
                ? d.credentials
                : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.cloudSyncCredential),
            items: [
              for (final o in options.credentials)
                DropdownMenuItem(
                  value: o.id,
                  child: Text(
                    o.detail.isEmpty ? o.name : '${o.name} (${o.detail})',
                  ),
                ),
            ],
            validator: (v) => v == null ? l10n.validationRequired : null,
            onChanged: (v) => setState(() => d.credentials = v),
          ),
        TextFormField(
          controller: _bucket,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l10n.cloudSyncBucket,
            helperText: l10n.cloudSyncBucketHint,
          ),
        ),
        TextFormField(
          controller: _folder,
          autocorrect: false,
          decoration: InputDecoration(labelText: l10n.cloudSyncFolder),
        ),
        TextFormField(
          controller: _path,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l10n.cloudSyncPath,
            helperText: l10n.cloudSyncPathHint,
            suffixIcon: IconButton(
              tooltip: l10n.pickDataset,
              icon: const Icon(Icons.list),
              onPressed: () async {
                final picked = await _pickDataset(context, options.datasets);
                if (picked != null) _path.text = '/mnt/$picked';
              },
            ),
          ),
          validator: (v) {
            final path = (v ?? '').trim();
            return path.startsWith('/mnt/') && path.length > 5
                ? null
                : l10n.cloudSyncPathInvalid;
          },
        ),
        DropdownButtonFormField<bool>(
          initialValue: d.push,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.directionLabel),
          items: [
            DropdownMenuItem(value: true, child: Text(l10n.cloudSyncPush)),
            DropdownMenuItem(value: false, child: Text(l10n.cloudSyncPull)),
          ],
          onChanged: (v) => setState(() => d.push = v!),
        ),
        DropdownButtonFormField<String>(
          initialValue: d.transferMode,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.transferModeLabel),
          items: [
            DropdownMenuItem(value: 'COPY', child: Text(l10n.transferCopy)),
            DropdownMenuItem(value: 'SYNC', child: Text(l10n.transferSync)),
            DropdownMenuItem(value: 'MOVE', child: Text(l10n.transferMove)),
          ],
          onChanged: (v) => setState(() => d.transferMode = v!),
        ),
        DropdownButtonFormField<Object?>(
          initialValue: d.schedule,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.snapshotTaskSchedule),
          items: _scheduleItems(l10n, d.schedule),
          onChanged: (v) => setState(() => d.schedule = v!),
        ),
      ],
    );
  }
}
