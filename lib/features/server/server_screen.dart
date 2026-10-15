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
      return Scaffold(
        appBar: AppBar(title: Text(instance?.name ?? '')),
        body: IndexedStack(
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
            MoreTab(session: session),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() => _tab = index),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: l10n.tabDashboard,
            ),
            NavigationDestination(
              icon: const Icon(Icons.storage_outlined),
              selectedIcon: const Icon(Icons.storage),
              label: l10n.tabStorage,
            ),
            NavigationDestination(
              icon: const Icon(Icons.folder_shared_outlined),
              selectedIcon: const Icon(Icons.folder_shared),
              label: l10n.tabShares,
            ),
            NavigationDestination(
              icon: const Icon(Icons.apps_outlined),
              selectedIcon: const Icon(Icons.apps),
              label: l10n.tabApps,
            ),
            NavigationDestination(
              icon: const Icon(Icons.more_horiz),
              label: l10n.tabMore,
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
