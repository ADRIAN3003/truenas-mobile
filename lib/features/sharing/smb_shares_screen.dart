import 'package:flutter/material.dart';

import '../../core/models/sharing.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/widgets.dart';
import '../storage/storage_helpers.dart';
import 'share_dialogs.dart';
import 'sharing_widgets.dart';

typedef _SmbData = (List<SmbShare>, ServiceEntry?);

/// SMB shares: list, add, edit, enable/disable and delete.
class SmbSharesScreen extends StatefulWidget {
  const SmbSharesScreen({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<SmbSharesScreen> createState() => _SmbSharesScreenState();
}

class _SmbSharesScreenState extends State<SmbSharesScreen>
    with LoadState<SmbSharesScreen, _SmbData> {
  TrueNasSession get _session => widget.session;

  @override
  Future<_SmbData> fetch() async {
    final (shares, services) = await (
      _session.sharing.smbShares(),
      _session.sharing.services(),
    ).wait;
    return (shares, services.where((s) => s.service == 'cifs').firstOrNull);
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final paths = await shareablePaths(_session);
    if (!mounted) return;
    final request = await showDialog<NewShareRequest>(
      context: context,
      builder: (_) => NewShareDialog(paths: paths, withName: true),
    );
    if (request == null || !mounted) return;
    final ok = await runWithFeedback(
      context,
      () => _session.sharing.createSmbShare(
        name: request.name!,
        path: request.path,
        comment: request.comment,
      ),
      success: l10n.shareCreated,
    );
    if (ok) await load();
  }

  Future<void> _update(SmbShare share, Map<String, Object?> changes) async {
    final l10n = AppLocalizations.of(context);
    final ok = await runWithFeedback(
      context,
      () => _session.sharing.updateSmbShare(share.id, changes),
      success: l10n.shareSaved,
    );
    if (ok) await load();
  }

  Future<void> _edit(SmbShare share) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<ShareEditResult>(
      context: context,
      builder: (_) => ShareEditDialog(
        title: share.name,
        comment: share.comment,
        enabled: share.enabled,
        readOnly: share.readOnly,
        browsable: share.browsable,
      ),
    );
    if (result == null || !mounted) return;
    if (result.delete) {
      final confirmed = await confirmAction(
        context,
        title: l10n.shareDeleteTitle(share.name),
        body: l10n.shareDeleteBody(share.path),
        confirmLabel: l10n.delete,
        cancelLabel: l10n.cancel,
        destructive: true,
      );
      if (!confirmed || !mounted) return;
      final ok = await runWithFeedback(
        context,
        () => _session.sharing.deleteSmbShare(share.id),
        success: l10n.shareDeleted,
      );
      if (ok) await load();
      return;
    }
    await _update(share, {
      'comment': result.comment,
      'enabled': result.enabled,
      share.readOnlyKey: result.readOnly,
      'browsable': result.browsable!,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.smbTitle)),
      floatingActionButton: data == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: Text(l10n.shareCreate),
            ),
      body: AsyncBody<_SmbData>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (data) {
          final (shares, service) = data;
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              if (service != null && !service.running && shares.isNotEmpty)
                ServiceStoppedBanner(
                  service: service,
                  onStart: () async {
                    await startService(context, _session, service);
                    await load();
                  },
                ),
              if (shares.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text(l10n.sharesEmpty)),
                ),
              for (final share in shares)
                ShareTile(
                  icon: Icons.folder_shared_outlined,
                  title: share.name,
                  lines: [
                    share.path,
                    if (share.comment.isNotEmpty) share.comment,
                  ],
                  enabled: share.enabled,
                  locked: share.locked,
                  readOnly: share.readOnly,
                  onToggle: (v) => _update(share, {'enabled': v}),
                  onTap: () => _edit(share),
                ),
            ],
          );
        },
      ),
    );
  }
}
