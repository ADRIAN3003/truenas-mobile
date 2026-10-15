import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/instances/instances_provider.dart';
import '../../core/instances/server_instance.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/connect_dialogs.dart';
import '../sharing/shares_tab.dart';
import '../storage/storage_tab.dart';
import '../workloads/apps_tab.dart';
import 'dashboard_tab.dart';
import 'more_tab.dart';

/// Window width from which the server screen uses a navigation rail.
const railBreakpoint = 600.0;

/// Connects to one saved server and shows its overview.
class ServerScreen extends ConsumerStatefulWidget {
  const ServerScreen(this.instanceId, {super.key});

  final String instanceId;

  @override
  ConsumerState<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends ConsumerState<ServerScreen> {
  TrueNasSession? _session;
  Map<String, dynamic>? _info;
  Object? _error;
  var _tab = 0;

  ServerInstance? get _instance => ref
      .read(instancesProvider)
      .value
      ?.where((e) => e.id == widget.instanceId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  @override
  void dispose() {
    _session?.close();
    super.dispose();
  }

  Future<void> _connect() async {
    final instance = _instance;
    if (instance == null) return;
    final previous = _session;
    _session = null;
    await previous?.close();
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      final (session, updated) = await connectToInstance(
        instance,
        confirmCertificate: (cert) => confirmCertificateDialog(context, cert),
        askOtp: () => askOtpDialog(context),
      );
      if (!mounted) {
        await session.close();
        return;
      }
      _session = session;
      if (updated.pinnedFingerprint != instance.pinnedFingerprint ||
          updated.lastApiVersion != instance.lastApiVersion) {
        await ref.read(instancesProvider.notifier).upsert(updated);
      }
      final info = await session.systemInfo();
      if (mounted) setState(() => _info = info);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final instance = _instance;
    final session = _session;
    final info = _info;
    if (session != null && info != null) {
      final destinations = [
        (Icons.dashboard_outlined, Icons.dashboard, l10n.tabDashboard),
        (Icons.storage_outlined, Icons.storage, l10n.tabStorage),
        (Icons.folder_shared_outlined, Icons.folder_shared, l10n.tabShares),
        (Icons.apps_outlined, Icons.apps, l10n.tabApps),
        (Icons.more_horiz, Icons.more_horiz, l10n.tabMore),
      ];
      final body = IndexedStack(
        index: _tab,
        children: [
          DashboardTab(
            session: session,
            info: info,
            onOpenAlerts: () => openAlerts(context, session),
          ),
          StorageTab(session: session),
          SharesTab(session: session),
          AppsTab(session: session),
          MoreTab(session: session, serverName: instance?.name ?? ''),
        ],
      );
      void select(int index) => setState(() => _tab = index);
      final width = MediaQuery.sizeOf(context).width;
      // Tablets and landscape phones get a side rail instead of a bottom bar.
      if (width >= railBreakpoint) {
        return Scaffold(
          appBar: AppBar(title: Text(instance?.name ?? '')),
          body: SafeArea(
            top: false,
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _tab,
                  onDestinationSelected: select,
                  extended: width >= 1200,
                  labelType: width >= 1200
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  destinations: [
                    for (final (icon, selected, label) in destinations)
                      NavigationRailDestination(
                        icon: Icon(icon),
                        selectedIcon: Icon(selected),
                        label: Text(label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(instance?.name ?? '')),
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: select,
          destinations: [
            for (final (icon, selected, label) in destinations)
              NavigationDestination(
                icon: Icon(icon),
                selectedIcon: Icon(selected),
                label: label,
              ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(instance?.name ?? '')),
      body: _error != null
          ? _ErrorState(
              message: describeConnectError(l10n, _error!),
              onRetry: _connect,
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.connecting),
                ],
              ),
            ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}
