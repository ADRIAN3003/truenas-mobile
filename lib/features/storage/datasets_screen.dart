import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/storage.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/formatting.dart';
import '../../shared/widgets.dart';
import 'storage_helpers.dart';
import '../../shared/dialogs.dart';

final _datasetName = RegExp(r'^[A-Za-z0-9_\-.:]+$');

/// Datasets and zvols of one pool, as an indented tree.
class DatasetsScreen extends StatefulWidget {
  const DatasetsScreen({super.key, required this.session, required this.pool});

  final TrueNasSession session;
  final String pool;

  @override
  State<DatasetsScreen> createState() => _DatasetsScreenState();
}

class _DatasetsScreenState extends State<DatasetsScreen> {
  List<Dataset>? _datasets;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final datasets = await widget.session.storage.datasets(widget.pool);
      if (!mounted) return;
      setState(() {
        _datasets = datasets;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _create() async {
    final datasets = _datasets;
    if (datasets == null) return;
    final l10n = AppLocalizations.of(context);
    final parents = [
      for (final d in datasets)
        if (!d.isVolume) d.id,
    ];
    if (parents.isEmpty) parents.add(widget.pool);
    final request = await showAppDialog<_CreateRequest>(
      context: context,
      builder: (_) => _CreateDatasetDialog(parents: parents),
    );
    if (request == null || !mounted) return;
    final ok = await runWithFeedback(
      context,
      () => request.sizeBytes == null
          ? widget.session.storage.createDataset(request.name)
          : widget.session.storage.createVolume(
              request.name,
              request.sizeBytes!,
            ),
      success: l10n.datasetCreated(request.name),
    );
    if (ok) await _load();
  }

  Future<void> _open(Dataset dataset) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            DatasetScreen(session: widget.session, dataset: dataset),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.datasetsTitle)),
      floatingActionButton: _datasets == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: Text(l10n.datasetCreate),
            ),
      body: AsyncBody<List<Dataset>>(
        value: _datasets,
        error: _error,
        onRefresh: _load,
        builder: (datasets) => datasets.isEmpty
            ? ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                children: [EmptyCard(l10n.datasetsEmpty)],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                children: [
                  GroupedCard(
                    indent: 16,
                    children: [
                      for (final dataset in datasets)
                        _DatasetTile(
                          dataset: dataset,
                          onTap: () => _open(dataset),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _DatasetTile extends StatelessWidget {
  const _DatasetTile({required this.dataset, required this.onTap});

  final Dataset dataset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.only(
        left: 16.0 + dataset.depth * 20,
        right: 16,
      ),
      leading: SoftIcon(
        dataset.isVolume ? Icons.storage_rounded : Icons.folder_rounded,
        dataset.isVolume ? AppPalette.tilePurple : AppPalette.tileBlue,
      ),
      title: Text(dataset.isRoot ? dataset.id : dataset.shortName),
      subtitle: Text(
        '${l10n.datasetUsed} ${formatBytes(dataset.used)}'
        ' · ${l10n.datasetAvailable} ${formatBytes(dataset.available)}',
      ),
      trailing: dataset.encrypted
          ? Icon(
              dataset.locked ? Icons.lock : Icons.lock_open,
              semanticLabel: dataset.locked
                  ? l10n.datasetLocked
                  : l10n.datasetEncrypted,
            )
          : null,
      onTap: onTap,
    );
  }
}

class _CreateRequest {
  const _CreateRequest(this.name, this.sizeBytes);

  final String name;

  /// Set for a zvol, null for a filesystem dataset.
  final int? sizeBytes;
}

class _CreateDatasetDialog extends StatefulWidget {
  const _CreateDatasetDialog({required this.parents});

  final List<String> parents;

  @override
  State<_CreateDatasetDialog> createState() => _CreateDatasetDialogState();
}

class _CreateDatasetDialogState extends State<_CreateDatasetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _size = TextEditingController();
  late String _parent = widget.parents.first;
  bool _volume = false;

  @override
  void dispose() {
    _name.dispose();
    _size.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final name = '$_parent/${_name.text.trim()}';
    final size = _volume
        ? (double.parse(_size.text.trim().replaceAll(',', '.')) *
                  1024 *
                  1024 *
                  1024)
              .round()
        : null;
    Navigator.pop(context, _CreateRequest(name, size));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: Text(l10n.datasetCreate),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.datasetTypeFilesystem),
                    icon: const Icon(Icons.folder_outlined),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.datasetTypeVolume),
                    icon: const Icon(Icons.storage_outlined),
                  ),
                ],
                selected: {_volume},
                onSelectionChanged: (s) => setState(() => _volume = s.first),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _parent,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.datasetParent),
                items: [
                  for (final p in widget.parents)
                    DropdownMenuItem(
                      value: p,
                      child: Text(p, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (p) => setState(() => _parent = p ?? _parent),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('datasetName'),
                controller: _name,
                autocorrect: false,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.datasetNameField),
                validator: (v) => _datasetName.hasMatch(v?.trim() ?? '')
                    ? null
                    : l10n.datasetNameInvalid,
              ),
              if (_volume) ...[
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('datasetSize'),
                  controller: _size,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: l10n.datasetSizeGib),
                  validator: (v) {
                    final size = double.tryParse(
                      (v ?? '').trim().replaceAll(',', '.'),
                    );
                    return size == null || size <= 0
                        ? l10n.datasetSizeInvalid
                        : null;
                  },
                ),
              ],
            ],
          ),
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
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// One dataset: properties and snapshots.
class DatasetScreen extends StatefulWidget {
  const DatasetScreen({
    super.key,
    required this.session,
    required this.dataset,
  });

  final TrueNasSession session;
  final Dataset dataset;

  @override
  State<DatasetScreen> createState() => _DatasetScreenState();
}

class _DatasetScreenState extends State<DatasetScreen> {
  List<Snapshot>? _snapshots;
  Object? _error;

  Dataset get _dataset => widget.dataset;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshots = await widget.session.storage.snapshots(_dataset.id);
      if (!mounted) return;
      setState(() {
        _snapshots = snapshots;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.datasetDeleteTitle(_dataset.id),
      body: l10n.datasetDeleteBody,
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      typeToConfirm: _dataset.id,
      typeToConfirmHint: l10n.typeNameToConfirm(_dataset.id),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await runWithFeedback(
      context,
      () => widget.session.storage.deleteDataset(_dataset.id),
      success: l10n.datasetDeleted(_dataset.id),
    );
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _createSnapshot() async {
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

  Future<void> _deleteSnapshot(Snapshot snapshot) async {
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
    final confirmed = await confirmAction(
      context,
      title: l10n.snapshotRollbackTitle(_dataset.shortName),
      body: l10n.snapshotRollbackBody(snapshot.name),
      confirmLabel: l10n.snapshotRollback,
      cancelLabel: l10n.cancel,
      typeToConfirm: _dataset.shortName,
      typeToConfirmHint: l10n.typeNameToConfirm(_dataset.shortName),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await runWithFeedback(
      context,
      () => widget.session.storage.rollbackSnapshot(
        snapshot.id,
        destroyNewer: true,
      ),
      success: l10n.snapshotRolledBack(snapshot.name),
    );
    if (ok) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dataset = _dataset;
    final snapshots = _snapshots;
    return Scaffold(
      appBar: AppBar(
        title: Text(dataset.shortName),
        actions: [
          if (!dataset.isRoot)
            IconButton(
              tooltip: l10n.datasetDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSnapshot,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(l10n.snapshotCreate),
      ),
      body: AppRefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dataset.id, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (dataset.isVolume)
                      InfoRow(
                        l10n.datasetVolsize,
                        formatBytes(dataset.volsize ?? 0),
                      ),
                    InfoRow(l10n.datasetUsed, formatBytes(dataset.used)),
                    InfoRow(
                      l10n.datasetAvailable,
                      formatBytes(dataset.available),
                    ),
                    if (dataset.compression != null)
                      InfoRow(l10n.datasetCompression, dataset.compression!),
                    if (dataset.compressRatio != null)
                      InfoRow(
                        l10n.datasetCompressRatio,
                        dataset.compressRatio!,
                      ),
                    if (dataset.mountpoint != null)
                      InfoRow(l10n.datasetMountpoint, dataset.mountpoint!),
                    InfoRow(
                      l10n.datasetEncryption,
                      !dataset.encrypted
                          ? l10n.datasetNotEncrypted
                          : dataset.locked
                          ? l10n.datasetLocked
                          : l10n.datasetEncrypted,
                    ),
                  ],
                ),
              ),
            ),
            SectionHeader(l10n.snapshotsTitle),
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
            else
              GroupedCard(
                indent: 72,
                children: [
                  for (final snapshot in snapshots)
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
                        onSelected: (action) => action == 'rollback'
                            ? _rollback(snapshot)
                            : _deleteSnapshot(snapshot),
                        entries: [
                          menuEntry('rollback', l10n.snapshotRollback),
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
              validator: (v) => _datasetName.hasMatch(v?.trim() ?? '')
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
