import 'package:flutter/material.dart';

import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
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
  const MoreTab({super.key, required this.session});

  final TrueNasSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text(l10n.tabAlerts),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openAlerts(context, session),
        ),
        ListTile(
          leading: const Icon(Icons.work_history_outlined),
          title: Text(l10n.tabJobs),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                appBar: AppBar(title: Text(l10n.tabJobs)),
                body: JobsTab(session: session),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
