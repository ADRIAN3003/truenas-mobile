import 'package:flutter/material.dart';

import '../../core/models/sharing.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../storage/storage_helpers.dart';
import 'sharing_widgets.dart';

typedef _IscsiData = (List<IscsiTarget>, List<IscsiExtent>);

/// iSCSI targets and extents (view only for now).
class IscsiScreen extends StatefulWidget {
  const IscsiScreen({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<IscsiScreen> createState() => _IscsiScreenState();
}

class _IscsiScreenState extends State<IscsiScreen>
    with LoadState<IscsiScreen, _IscsiData> {
  @override
  Future<_IscsiData> fetch() => (
    widget.session.sharing.iscsiTargets(),
    widget.session.sharing.iscsiExtents(),
  ).wait;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.iscsiTitle)),
      body: AsyncBody<_IscsiData>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (data) {
          final (targets, extents) = data;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const _ViewOnlyNote(),
              if (targets.isEmpty && extents.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text(l10n.iscsiEmpty)),
                ),
              if (targets.isNotEmpty) _Heading(l10n.iscsiTargets),
              for (final target in targets)
                ListTile(
                  leading: const Icon(Icons.adjust),
                  title: Text(target.name),
                  subtitle: target.alias == null || target.alias!.isEmpty
                      ? null
                      : Text(target.alias!),
                  trailing: target.mode == null || target.mode == 'ISCSI'
                      ? null
                      : Text(target.mode!),
                ),
              if (extents.isNotEmpty) _Heading(l10n.iscsiExtents),
              for (final extent in extents)
                ListTile(
                  leading: Icon(
                    extent.type == 'FILE'
                        ? Icons.insert_drive_file_outlined
                        : Icons.storage_outlined,
                  ),
                  title: Text(extent.name),
                  subtitle: Text(
                    [
                      ?extent.source,
                      if (!extent.enabled) l10n.shareDisabled,
                      if (extent.readOnly) l10n.shareReadOnly,
                    ].join(' · '),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// NVMe-oF subsystems (25.10 and newer; view only for now).
class NvmetScreen extends StatefulWidget {
  const NvmetScreen({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<NvmetScreen> createState() => _NvmetScreenState();
}

class _NvmetScreenState extends State<NvmetScreen>
    with LoadState<NvmetScreen, List<NvmetSubsystem>> {
  @override
  Future<List<NvmetSubsystem>> fetch() =>
      widget.session.sharing.nvmetSubsystems();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.nvmetTitle)),
      body: AsyncBody<List<NvmetSubsystem>>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (subsystems) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const _ViewOnlyNote(),
            if (subsystems.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(l10n.nvmetEmpty)),
              ),
            for (final subsystem in subsystems)
              ListTile(
                leading: const Icon(Icons.memory),
                title: Text(subsystem.name),
                subtitle: Text(
                  [
                    ?subsystem.nqn,
                    subsystem.allowAnyHost
                        ? l10n.nvmetAnyHost
                        : l10n.nvmetAllowedHosts,
                  ].join('\n'),
                ),
                isThreeLine: subsystem.nqn != null,
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewOnlyNote extends StatelessWidget {
  const _ViewOnlyNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context).viewOnlyNote,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}
