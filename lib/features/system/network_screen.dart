import 'package:flutter/material.dart';

import '../../core/models/system.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/viz_colors.dart';
import '../../shared/widgets.dart';
import '../sharing/sharing_widgets.dart';
import '../storage/storage_helpers.dart';

typedef _NetworkData = (String?, NetworkSummary, List<NetInterface>);

/// Hostname, gateways, DNS servers and interfaces with their addresses.
class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen>
    with LoadState<NetworkScreen, _NetworkData> {
  @override
  Future<_NetworkData> fetch() => (
    widget.session.system.hostname(),
    widget.session.system.networkSummary(),
    widget.session.system.interfaces(),
  ).wait;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String list(List<String> values) =>
        values.isEmpty ? l10n.networkNone : values.join('\n');
    return Scaffold(
      appBar: AppBar(title: Text(l10n.networkTitle)),
      body: AsyncBody<_NetworkData>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (data) {
          final (hostname, summary, interfaces) = data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              GroupedCard(
                children: [
                  ListTile(
                    leading: const IconTile(
                      Icons.dns_rounded,
                      AppPalette.tileBlue,
                    ),
                    title: Text(l10n.networkHostname),
                    subtitle: Text(hostname ?? l10n.networkNone),
                  ),
                  ListTile(
                    leading: const IconTile(
                      Icons.router_rounded,
                      AppPalette.tileTeal,
                    ),
                    title: Text(l10n.networkGateway),
                    subtitle: Text(list(summary.defaultRoutes)),
                  ),
                  ListTile(
                    leading: const IconTile(
                      Icons.travel_explore_rounded,
                      AppPalette.tilePurple,
                    ),
                    title: Text(l10n.networkDns),
                    subtitle: Text(list(summary.nameservers)),
                  ),
                ],
              ),
              ...groupedSection(l10n.networkInterfaces, indent: 64, [
                for (final iface in interfaces)
                  ListTile(
                    leading: IconTile(
                      Icons.settings_ethernet_rounded,
                      iface.linkUp
                          ? AppPalette.tileGreen
                          : AppPalette.tileSlate,
                    ),
                    title: Text(
                      iface.description == null
                          ? iface.name
                          : '${iface.name} · ${iface.description}',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(list(summary.addresses[iface.name] ?? const [])),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 12,
                            children: [
                              iface.linkUp
                                  ? StatusLabel(
                                      icon: Icons.check_circle,
                                      color: VizColors.good,
                                      label: l10n.networkLinkUp,
                                    )
                                  : StatusLabel(
                                      icon: Icons.link_off,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      label: l10n.networkLinkDown,
                                    ),
                              if (iface.dhcp) Text(l10n.networkDhcp),
                              if (iface.mtu case final mtu?) Text('MTU $mtu'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ]),
            ],
          );
        },
      ),
    );
  }
}

/// Certificates and when they expire.
class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen>
    with LoadState<CertificatesScreen, List<CertificateInfo>> {
  @override
  Future<List<CertificateInfo>> fetch() => widget.session.system.certificates();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.certificatesTitle)),
      body: AsyncBody<List<CertificateInfo>>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (certs) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (certs.isEmpty) EmptyCard(l10n.certificatesEmpty),
            if (certs.isNotEmpty)
              GroupedCard(
                indent: 72,
                children: [
                  for (final cert in certs)
                    ListTile(
                      leading: IconTile(
                        Icons.verified_rounded,
                        cert.expired
                            ? AppPalette.tileRed
                            : AppPalette.tileGreen,
                        size: 40,
                      ),
                      title: Text(cert.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (cert.commonName case final cn?) Text(cn),
                          if (cert.san.isNotEmpty)
                            Text(
                              cert.san.join(', '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (cert.expired)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: StatusLabel(
                                icon: Icons.error_outline,
                                color: VizColors.critical,
                                label: l10n.certificateExpired,
                              ),
                            )
                          else if (cert.until case final until?)
                            Text(l10n.certificateValidUntil(until)),
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
