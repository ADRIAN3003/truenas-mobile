import 'package:flutter/material.dart';

import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/widgets.dart';
import '../storage/storage_helpers.dart';
import '../explorer/api_explorer_screen.dart';
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
    final theme = Theme.of(context);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );
    Widget entry(IconData icon, String title, Widget Function() screen) =>
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(context, screen()),
        );
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        header(l10n.moreAccounts),
        entry(
          Icons.people_outline,
          l10n.usersTitle,
          () => UsersScreen(session: session),
        ),
        entry(
          Icons.key_outlined,
          l10n.apiKeysTitle,
          () => ApiKeysScreen(session: session),
        ),
        header(l10n.moreSystem),
        entry(
          Icons.lan_outlined,
          l10n.networkTitle,
          () => NetworkScreen(session: session),
        ),
        entry(
          Icons.verified_outlined,
          l10n.certificatesTitle,
          () => CertificatesScreen(session: session),
        ),
        entry(
          Icons.system_update_outlined,
          l10n.updatesTitle,
          () => UpdatesScreen(session: session),
        ),
        header(l10n.moreTools),
        entry(
          Icons.terminal,
          l10n.shellTitle,
          () => ShellScreen(session: session),
        ),
        entry(
          Icons.api,
          l10n.explorerTitle,
          () => ApiExplorerScreen(session: session),
        ),
        header(l10n.moreActivity),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text(l10n.tabAlerts),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openAlerts(context, session),
        ),
        entry(
          Icons.work_history_outlined,
          l10n.tabJobs,
          () => Scaffold(
            appBar: AppBar(title: Text(l10n.tabJobs)),
            body: JobsTab(session: session),
          ),
        ),
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.restart_alt),
          title: Text(l10n.powerReboot),
          onTap: () => _power(context, reboot: true),
        ),
        ListTile(
          leading: Icon(
            Icons.power_settings_new,
            color: theme.colorScheme.error,
          ),
          title: Text(
            l10n.powerShutdown,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          onTap: () => _power(context, reboot: false),
        ),
      ],
    );
  }
}
