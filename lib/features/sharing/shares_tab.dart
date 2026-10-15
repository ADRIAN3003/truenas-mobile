import 'package:flutter/material.dart';

import '../../core/models/sharing.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../storage/storage_helpers.dart';
import 'block_shares_screen.dart';
import 'nfs_shares_screen.dart';
import 'services_screen.dart';
import 'sharing_widgets.dart';
import 'smb_shares_screen.dart';

/// What the Shares tab shows. Block sharing parts are null when the
/// server doesn't offer them or the user may not read them.
class _Overview {
  const _Overview({
    required this.services,
    required this.smb,
    required this.nfs,
    this.iscsi,
    this.nvmet,
  });

  final List<ServiceEntry> services;
  final List<SmbShare> smb;
  final List<NfsShare> nfs;
  final (int, int)? iscsi;
  final int? nvmet;

  ServiceEntry? service(String name) =>
      services.where((s) => s.service == name).firstOrNull;
}

/// File and block sharing at a glance, plus the way into services.
class SharesTab extends StatefulWidget {
  const SharesTab({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<SharesTab> createState() => _SharesTabState();
}

class _SharesTabState extends State<SharesTab>
    with LoadState<SharesTab, _Overview> {
  @override
  Future<_Overview> fetch() async {
    final sharing = widget.session.sharing;
    Future<T?> optional<T>(Future<T> Function() f) async {
      try {
        return await f();
      } catch (_) {
        return null;
      }
    }

    final (services, smb, nfs, iscsi, nvmet) = await (
      sharing.services(),
      sharing.smbShares(),
      sharing.nfsShares(),
      optional(
        () async => (
          (await sharing.iscsiTargets()).length,
          (await sharing.iscsiExtents()).length,
        ),
      ),
      optional(
        () async => await sharing.hasNvmet()
            ? (await sharing.nvmetSubsystems()).length
            : null,
      ),
    ).wait;
    return _Overview(
      services: services,
      smb: smb,
      nfs: nfs,
      iscsi: iscsi,
      nvmet: nvmet,
    );
  }

  Future<void> _open(Widget Function() screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => screen()),
    );
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = widget.session;
    return AsyncBody<_Overview>(
      value: data,
      error: error,
      onRefresh: load,
      builder: (o) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _EntryCard(
            icon: Icons.folder_shared_outlined,
            title: l10n.smbTitle,
            subtitle: l10n.sharesCount(o.smb.length),
            service: o.service('cifs'),
            onTap: () => _open(() => SmbSharesScreen(session: session)),
          ),
          _EntryCard(
            icon: Icons.lan_outlined,
            title: l10n.nfsTitle,
            subtitle: l10n.sharesCount(o.nfs.length),
            service: o.service('nfs'),
            onTap: () => _open(() => NfsSharesScreen(session: session)),
          ),
          if (o.iscsi case (final targets, final extents))
            _EntryCard(
              icon: Icons.adjust,
              title: l10n.iscsiTitle,
              subtitle: l10n.iscsiSummary(targets, extents),
              service: o.service('iscsitarget'),
              onTap: () => _open(() => IscsiScreen(session: session)),
            ),
          if (o.nvmet case final count?)
            _EntryCard(
              icon: Icons.memory,
              title: l10n.nvmetTitle,
              subtitle: l10n.nvmetSummary(count),
              service: o.service('nvmet'),
              onTap: () => _open(() => NvmetScreen(session: session)),
            ),
          const SizedBox(height: 8),
          _EntryCard(
            icon: Icons.miscellaneous_services_outlined,
            title: l10n.servicesTitle,
            subtitle: l10n.servicesSubtitle,
            onTap: () => _open(() => ServicesScreen(session: session)),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.service,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ServiceEntry? service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final service = this.service;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            if (service != null) ...[
              const SizedBox(height: 4),
              ServiceStateLabel(service: service),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
