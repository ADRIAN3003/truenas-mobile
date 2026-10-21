import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/storage.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/dialogs.dart';
import '../../shared/formatting.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import 'storage_helpers.dart';

final _namePart = RegExp(r'^[A-Za-z0-9_\-.:]+$');

enum _SnapshotSort { newest, oldest, name, size }

/// The snapshots of one dataset: search, sort, create, roll back, clone and
/// delete.
class SnapshotsScreen extends StatefulWidget {
  const SnapshotsScreen({
    super.key,
    required this.session,
    required this.dataset,
  });

  final TrueNasSession session;
  final Dataset dataset;

  @override
  State<SnapshotsScreen> createState() => _SnapshotsScreenState();
}

class _SnapshotsScreenState extends State<SnapshotsScreen> {
  List<Snapshot>? _snapshots;
  Object? _error;
  bool _canClone = false;
  String _query = '';
  _SnapshotSort _sort = _SnapshotSort.newest;

  Dataset get _dataset => widget.dataset;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final storage = widget.session.storage;
      final snapshots = await storage.snapshots(_dataset.id);
      final canClone = await storage.canCloneSnapshots();
      if (!mounted) return;
      setState(() {
        _snapshots = snapshots;
        _canClone = canClone;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  /// The snapshots to show: filtered by the search and in the chosen order.
  List<Snapshot> _visible(List<Snapshot> all) {
    final query = _query.trim().toLowerCase();
    final shown = [
      for (final s in all)
        if (query.isEmpty || s.name.toLowerCase().contains(query)) s,
    ];
    int byDate(Snapshot a, Snapshot b) =>
        (a.created ?? DateTime(0)).compareTo(b.created ?? DateTime(0));
    switch (_sort) {
      case _SnapshotSort.newest:
        shown.sort((a, b) => byDate(b, a));
      case _SnapshotSort.oldest:
        shown.sort(byDate);
      case _SnapshotSort.name:
        shown.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _SnapshotSort.size:
        shown.sort((a, b) => b.used.compareTo(a.used));
    }
    return shown;
  }

  /// Snapshots taken after [snapshot]. Rolling back destroys them.
  List<Snapshot> _newerThan(Snapshot snapshot) {
    final created = snapshot.created;
    if (created == null) return const [];
    return [
      for (final s in _snapshots ?? const <Snapshot>[])
        if (s.created != null && s.created!.isAfter(created)) s,
    ]..sort((a, b) => b.created!.compareTo(a.created!));
  }

  Future<void> _pickSort() async {
    final l10n = AppLocalizations.of(context);
    final labels = {
      _SnapshotSort.newest: l10n.snapshotSortNewest,
      _SnapshotSort.oldest: l10n.snapshotSortOldest,
      _SnapshotSort.name: l10n.snapshotSortName,
      _SnapshotSort.size: l10n.snapshotSortSize,
    };
    final choice = await showAppChoice<_SnapshotSort>(
      context: context,
      title: l10n.snapshotSort,
      choices: [
        for (final sort in _SnapshotSort.values)
          appChoice(sort, labels[sort]!, selected: sort == _sort),
      ],
    );
    if (choice != null && mounted) setState(() => _sort = choice.$1);
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final request = await showAppDialog<(String, bool)>(
      context: context,
      builder: (_) => const _CreateSnapshotDialog(),
    );
    if (request == null || !mounted) return;
    final (name, recursive) = request;
    final ok = await runWithFeedback(
      context,
      () => widget.session.storage.createSnapshot(
        _dataset.id,
        name,
        recursive: recursive,
      ),
      success: l10n.snapshotCreated,
    );
    if (ok) await _load();
  }

  Future<void> _delete(Snapshot snapshot) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.snapshotDeleteTitle(snapshot.name),
      body: l10n.snapshotDeleteBody,
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await runWithFeedback(
      context,
      () => widget.session.storage.deleteSnapshot(snapshot.id),
      success: l10n.snapshotDeleted,
    );
    if (ok) await _load();
  }

  Future<void> _rollback(Snapshot snapshot) async {
    final l10n = AppLocalizations.of(context);
    final newer = _newerThan(snapshot);
    final options = await showAppDialog<(bool, bool)>(
      context: context,
      builder: (_) =>
          _RollbackDialog(dataset: _dataset, snapshot: snapshot, newer: newer),
    );
    if (options == null || !mounted) return;
    final (destroyClones, force) = options;
    final ok = await runWithFeedback(
      context,
      () => widget.session.storage.rollbackSnapshot(
        snapshot.id,
        destroyNewer: newer.isNotEmpty,
        destroyClones: destroyClones,
        force: force,
      ),
      success: l10n.snapshotRolledBack(snapshot.name),
    );
    if (ok) await _load();
  }

  Future<void> _clone(Snapshot snapshot) async {
    final l10n = AppLocalizations.of(context);
    final target = await showAppDialog<String>(
      context: context,
      builder: (_) => _CloneDialog(dataset: _dataset, snapshot: snapshot),
    );
    if (target == null || !mounted) return;
    await runWithFeedback(
      context,
      () => widget.session.storage.cloneSnapshot(snapshot.id, target),
      success: l10n.snapshotCloned(target),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final snapshots = _snapshots;
    final shown = snapshots == null ? const <Snapshot>[] : _visible(snapshots);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.snapshotsTitle),
        actions: [
          IconButton(
            tooltip: l10n.snapshotSort,
            icon: const Icon(Icons.sort_rounded),
            onPressed: _pickSort,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(l10n.snapshotCreate),
      ),
      body: AppRefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          children: [
            Text(_dataset.id, style: Theme.of(context).textTheme.titleMedium),
            if (snapshots != null && snapshots.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                l10n.snapshotsSummary(
                  snapshots.length,
                  formatBytes(snapshots.fold(0, (sum, s) => sum + s.used)),
                ),
                style: TextStyle(color: AppPalette.of(context).muted),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('snapshotSearch'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: l10n.snapshotsSearch,
                ),
                autocorrect: false,
                onChanged: (value) => setState(() => _query = value),
              ),
            ],
            const SizedBox(height: 8),
            if (snapshots == null && _error == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator.adaptive()),
              )
            else if (snapshots == null)
              AsyncBody<List<Snapshot>>(
                value: null,
                error: _error,
                onRefresh: _load,
                builder: (_) => const SizedBox.shrink(),
              )
            else if (snapshots.isEmpty)
              EmptyCard(l10n.snapshotsEmpty)
            else if (shown.isEmpty)
              EmptyCard(l10n.snapshotsNoMatch)
            else
              GroupedCard(
                indent: 72,
                children: [
                  for (final snapshot in shown)
                    ListTile(
                      leading: const SoftIcon(
                        Icons.photo_camera_rounded,
                        AppPalette.tileTeal,
                      ),
                      title: Text(snapshot.name),
                      subtitle: Text(
                        [
                          if (snapshot.created != null)
                            DateFormat.yMMMd(locale)
                                .add_Hm()
                                .format(snapshot.created!),
                          l10n.snapshotSize(
                            formatBytes(snapshot.used),
                            formatBytes(snapshot.referenced),
                          ),
                        ].join('\n'),
                      ),
                      isThreeLine: snapshot.created != null,
                      trailing: AppPopupMenu<String>(
                        onSelected: (action) => switch (action) {
                          'rollback' => _rollback(snapshot),
                          'clone' => _clone(snapshot),
                          _ => _delete(snapshot),
                        },
                        entries: [
                          menuEntry('rollback', l10n.snapshotRollback),
                          if (_canClone) menuEntry('clone', l10n.snapshotClone),
                          menuEntry(
                            'delete',
                            l10n.snapshotDelete,
                            destructive: true,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Asks before rolling back: names the snapshots that would be lost and wants
/// the dataset's name typed. Pops `(destroyClones, force)`.
class _RollbackDialog extends StatefulWidget {
  const _RollbackDialog({
    required this.dataset,
    required this.snapshot,
    required this.newer,
  });

  final Dataset dataset;
  final Snapshot snapshot;
  final List<Snapshot> newer;

  @override
  State<_RollbackDialog> createState() => _RollbackDialogState();
}

class _RollbackDialogState extends State<_RollbackDialog> {
  final _typed = TextEditingController();
  bool _destroyClones = false;
  bool _force = false;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = widget.dataset.shortName;
    final newer = widget.newer;
    const shownMax = 5;
    return AppDialog(
      title: Text(l10n.snapshotRollbackTitle(name)),
      message: l10n.snapshotRollbackBody(widget.snapshot.name),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (newer.isNotEmpty) ...[
            Text(
              l10n.snapshotRollbackNewer(newer.length),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            for (final s in newer.take(shownMax)) Text('• ${s.name}'),
            if (newer.length > shownMax)
              Text(l10n.snapshotRollbackMore(newer.length - shownMax)),
            CheckboxListTile(
              key: const Key('rollbackClones'),
              contentPadding: EdgeInsets.zero,
              value: _destroyClones,
              title: Text(l10n.snapshotRollbackClones),
              onChanged: (v) => setState(() => _destroyClones = v ?? false),
            ),
          ],
          CheckboxListTile(
            key: const Key('rollbackForce'),
            contentPadding: EdgeInsets.zero,
            value: _force,
            title: Text(l10n.snapshotRollbackForce),
            onChanged: (v) => setState(() => _force = v ?? false),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _typed,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.typeNameToConfirm(name),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        dialogAction(
          context,
          label: l10n.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        dialogAction(
          context,
          label: l10n.snapshotRollback,
          primary: true,
          destructive: true,
          onPressed: _typed.text.trim() == name
              ? () => Navigator.pop(context, (_destroyClones, _force))
              : null,
        ),
      ],
    );
  }
}

/// Asks for the new dataset's path. Pops it.
class _CloneDialog extends StatefulWidget {
  const _CloneDialog({required this.dataset, required this.snapshot});

  final Dataset dataset;
  final Snapshot snapshot;

  @override
  State<_CloneDialog> createState() => _CloneDialogState();
}

class _CloneDialogState extends State<_CloneDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _target = TextEditingController(
    text: '${widget.dataset.id}-clone',
  );

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  bool _valid(String value) {
    final parts = value.split('/');
    return parts.length >= 2 &&
        parts.first == widget.dataset.pool &&
        parts.every(_namePart.hasMatch);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pool = widget.dataset.pool;
    return AppDialog(
      title: Text(l10n.snapshotCloneTitle(widget.snapshot.name)),
      message: l10n.snapshotCloneBody,
      scrollable: true,
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('cloneTarget'),
          controller: _target,
          autocorrect: false,
          decoration: InputDecoration(labelText: l10n.snapshotCloneTarget),
          validator: (v) =>
              _valid(v?.trim() ?? '') ? null : l10n.snapshotCloneInvalid(pool),
        ),
      ),
      actions: [
        dialogAction(
          context,
          label: l10n.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        dialogAction(
          context,
          label: l10n.snapshotClone,
          primary: true,
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, _target.text.trim());
          },
        ),
      ],
    );
  }
}

class _CreateSnapshotDialog extends StatefulWidget {
  const _CreateSnapshotDialog();

  @override
  State<_CreateSnapshotDialog> createState() => _CreateSnapshotDialogState();
}

class _CreateSnapshotDialogState extends State<_CreateSnapshotDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: 'manual-${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}',
  );
  bool _recursive = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: Text(l10n.snapshotCreate),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('snapshotName'),
              controller: _name,
              autocorrect: false,
              decoration: InputDecoration(labelText: l10n.snapshotNameField),
              validator: (v) => _namePart.hasMatch(v?.trim() ?? '')
                  ? null
                  : l10n.datasetNameInvalid,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _recursive,
              title: Text(l10n.snapshotRecursive),
              onChanged: (v) => setState(() => _recursive = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        dialogAction(
          context,
          label: l10n.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        dialogAction(
          context,
          label: l10n.create,
          primary: true,
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, (_name.text.trim(), _recursive));
          },
        ),
      ],
    );
  }
}
