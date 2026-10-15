import 'package:flutter/material.dart';

import '../../core/models/sharing.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../storage/storage_helpers.dart';
import 'share_dialogs.dart';
import 'sharing_widgets.dart';

typedef _NfsData = (List<NfsShare>, ServiceEntry?);

/// NFS exports: list, add, edit, enable/disable and delete.
class NfsSharesScreen extends StatefulWidget {
  const NfsSharesScreen({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<NfsSharesScreen> createState() => _NfsSharesScreenState();
}

class _NfsSharesScreenState extends State<NfsSharesScreen>
    with LoadState<NfsSharesScreen, _NfsData> {
  TrueNasSession get _session => widget.session;

  @override
  Future<_NfsData> fetch() async {
    final (shares, services) = await (
      _session.sharing.nfsShares(),
      _session.sharing.services(),
    ).wait;
    return (shares, services.where((s) => s.service == 'nfs').firstOrNull);
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final paths = await shareablePaths(_session);
    if (!mounted) return;
    final request = await showDialog<NewShareRequest>(
      context: context,
      builder: (_) => NewShareDialog(paths: paths, withName: false),
    );
    if (request == null || !mounted) return;
    final ok = await runWithFeedback(
      context,
      () => _session.sharing.createNfsShare(
        path: request.path,
        comment: request.comment,
        readOnly: request.readOnly,
      ),
      success: l10n.shareCreated,
    );
    if (ok) await load();
  }

  Future<void> _update(NfsShare share, Map<String, Object?> changes) async {
    final l10n = AppLocalizations.of(context);
    final ok = await runWithFeedback(
      context,
      () => _session.sharing.updateNfsShare(share.id, changes),
      success: l10n.shareSaved,
    );
    if (ok) await load();
  }

  Future<void> _edit(NfsShare share) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<ShareEditResult>(
      context: context,
      builder: (_) => ShareEditDialog(
        title: share.path,
        comment: share.comment,
        enabled: share.enabled,
        readOnly: share.readOnly,
      ),
    );
    if (result == null || !mounted) return;
    if (result.delete) {
      final confirmed = await confirmAction(
        context,
        title: l10n.shareDeleteTitle(share.path),
        body: l10n.shareDeleteBody(share.path),
        confirmLabel: l10n.delete,
        cancelLabel: l10n.cancel,
        destructive: true,
      );
      if (!confirmed || !mounted) return;
      final ok = await runWithFeedback(
        context,
        () => _session.sharing.deleteNfsShare(share.id),
        success: l10n.shareDeleted,
      );
      if (ok) await load();
      return;
    }
    await _update(share, {
      'comment': result.comment,
      'enabled': result.enabled,
      'ro': result.readOnly,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.nfsTitle)),
      floatingActionButton: data == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: Text(l10n.shareCreate),
            ),
      body: AsyncBody<_NfsData>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (data) {
          final (shares, service) = data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            children: [
              if (service != null && !service.running && shares.isNotEmpty)
                ServiceStoppedBanner(
                  service: service,
                  onStart: () async {
                    await startService(context, _session, service);
                    await load();
                  },
                ),
              if (shares.isEmpty) EmptyCard(l10n.sharesEmpty),
              if (shares.isNotEmpty)
                GroupedCard(
                  children: [
                    for (final share in shares)
                      ShareTile(
                        icon: Icons.lan_outlined,
                        title: share.path,
                        lines: [
                          if (share.comment.isNotEmpty) share.comment,
                          share.networks.isEmpty && share.hosts.isEmpty
                              ? l10n.nfsAllowedEveryone
                              : l10n.nfsAllowed(
                                  [
                                    ...share.networks,
                                    ...share.hosts,
                                  ].join(', '),
                                ),
                        ],
                        enabled: share.enabled,
                        locked: share.locked,
                        readOnly: share.readOnly,
                        onToggle: (v) => _update(share, {'enabled': v}),
                        onTap: () => _edit(share),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
