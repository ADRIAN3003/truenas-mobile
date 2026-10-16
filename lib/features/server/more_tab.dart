import 'package:flutter/material.dart';

import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glass.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../storage/storage_helpers.dart';
import '../explorer/api_explorer_screen.dart';
import '../settings/settings_screen.dart';
import '../shell/shell_screen.dart';
import '../system/api_keys_screen.dart';
import '../system/network_screen.dart';
import '../system/updates_screen.dart';
import '../system/users_screen.dart';
import 'alerts_tab.dart';
import 'jobs_tab.dart';

/// Opens the alerts list as its own screen.
Future<void> openAlerts(BuildContext context, TrueNasSession session) =>
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(AppLocalizations.of(context).tabAlerts)),
          body: AlertsTab(session: session),
        ),
      ),
    );

/// Everything that doesn't need a tab of its own.
class MoreTab extends StatelessWidget {
  const MoreTab({super.key, required this.session, required this.serverName});

  final TrueNasSession session;

  /// The name the user gave this server, for power confirmations.
  final String serverName;

  void _open(BuildContext context, Widget screen) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (context) => screen),
  );

  Future<void> _power(BuildContext context, {required bool reboot}) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await confirmAction(
      context,
      title: reboot
          ? l10n.powerRebootTitle(serverName)
          : l10n.powerShutdownTitle(serverName),
      body: reboot ? l10n.powerRebootBody : l10n.powerShutdownBody,
      confirmLabel: reboot ? l10n.restart : l10n.shutDown,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final ok = await runWithFeedback(
      context,
      reboot ? session.system.reboot : session.system.shutdown,
      success: reboot
          ? l10n.powerRebooting(serverName)
          : l10n.powerShuttingDown(serverName),
    );
    // The connection is about to drop, so go back to the server list.
    if (ok) navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    Widget entry(
      IconData icon,
      Color color,
      String title,
      Widget Function() screen,
    ) => NavRow(
      icon: icon,
      color: color,
      title: title,
      onTap: () => _open(context, screen()),
    );
    return ListView(
      padding: ChromeInsets.pad(
        context,
        const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
      children: [
        SectionHeader(l10n.moreAccounts),
        GroupedCard(
          children: [
            entry(
              Icons.people_rounded,
              AppPalette.tileBlue,
              l10n.usersTitle,
              () => UsersScreen(session: session),
            ),
            entry(
              Icons.key_rounded,
              AppPalette.tileOrange,
              l10n.apiKeysTitle,
              () => ApiKeysScreen(session: session),
            ),
          ],
        ),
        SectionHeader(l10n.moreSystem),
        GroupedCard(
          children: [
            entry(
              Icons.lan_rounded,
              AppPalette.tileTeal,
              l10n.networkTitle,
              () => NetworkScreen(session: session),
            ),
            entry(
              Icons.verified_rounded,
              AppPalette.tileGreen,
              l10n.certificatesTitle,
              () => CertificatesScreen(session: session),
            ),
            entry(
              Icons.system_update_rounded,
              AppPalette.tilePurple,
              l10n.updatesTitle,
              () => UpdatesScreen(session: session),
            ),
          ],
        ),
        SectionHeader(l10n.moreTools),
        GroupedCard(
          children: [
            entry(
              Icons.terminal_rounded,
              AppPalette.tileSlate,
              l10n.shellTitle,
              () => ShellScreen(session: session),
            ),
            entry(
              Icons.api_rounded,
              AppPalette.tileBlue,
              l10n.explorerTitle,
              () => ApiExplorerScreen(session: session),
            ),
            entry(
              Icons.settings_rounded,
              AppPalette.tileSlate,
              l10n.settingsTitle,
              () => const SettingsScreen(),
            ),
          ],
        ),
        SectionHeader(l10n.moreActivity),
        GroupedCard(
          children: [
            NavRow(
              icon: Icons.notifications_rounded,
              color: AppPalette.tileRed,
              title: l10n.tabAlerts,
              onTap: () => openAlerts(context, session),
            ),
            entry(
              Icons.work_history_rounded,
              AppPalette.tileTeal,
              l10n.tabJobs,
              () => Scaffold(
                appBar: AppBar(title: Text(l10n.tabJobs)),
                body: JobsTab(session: session),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GroupedCard(
          children: [
            NavRow(
              icon: Icons.restart_alt_rounded,
              color: AppPalette.tileOrange,
              title: l10n.powerReboot,
              trailing: const SizedBox.shrink(),
              onTap: () => _power(context, reboot: true),
            ),
            ListTile(
              leading: const IconTile(
                Icons.power_settings_new_rounded,
                AppPalette.tileRed,
              ),
              title: Text(
                l10n.powerShutdown,
                style: TextStyle(color: palette.critical),
              ),
              onTap: () => _power(context, reboot: false),
            ),
          ],
        ),
      ],
    );
  }
}
