import 'package:flutter/material.dart';

import '../../core/models/sharing.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glass.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
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
        padding: ChromeInsets.pad(
          context,
          const EdgeInsets.fromLTRB(16, 8, 16, 24),
        ),
        children: [
          ...groupedSection(l10n.tabShares, indent: 64, [
            NavRow(
              icon: Icons.folder_shared_rounded,
              color: AppPalette.tileBlue,
              title: l10n.smbTitle,
              subtitle: l10n.sharesCount(o.smb.length),
              detail: _state(o.service('cifs')),
              onTap: () => _open(() => SmbSharesScreen(session: session)),
            ),
            NavRow(
              icon: Icons.lan_rounded,
              color: AppPalette.tileTeal,
              title: l10n.nfsTitle,
              subtitle: l10n.sharesCount(o.nfs.length),
              detail: _state(o.service('nfs')),
              onTap: () => _open(() => NfsSharesScreen(session: session)),
            ),
            if (o.iscsi case (final targets, final extents))
              NavRow(
                icon: Icons.adjust_rounded,
                color: AppPalette.tilePurple,
                title: l10n.iscsiTitle,
                subtitle: l10n.iscsiSummary(targets, extents),
                detail: _state(o.service('iscsitarget')),
                onTap: () => _open(() => IscsiScreen(session: session)),
              ),
            if (o.nvmet case final count?)
              NavRow(
                icon: Icons.memory_rounded,
                color: AppPalette.tileOrange,
                title: l10n.nvmetTitle,
                subtitle: l10n.nvmetSummary(count),
                detail: _state(o.service('nvmet')),
                onTap: () => _open(() => NvmetScreen(session: session)),
              ),
          ]),
          const SizedBox(height: 20),
          GroupedCard(
            children: [
              NavRow(
                icon: Icons.miscellaneous_services_rounded,
                color: AppPalette.tileSlate,
                title: l10n.servicesTitle,
                subtitle: l10n.servicesSubtitle,
                onTap: () => _open(() => ServicesScreen(session: session)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _state(ServiceEntry? service) =>
      service == null ? null : ServiceStateLabel(service: service);
}
