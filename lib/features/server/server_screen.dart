import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/instances/instances_provider.dart';
import '../../core/instances/server_instance.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/connect_dialogs.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(instance?.name ?? '')),
      body: switch ((_info, _error)) {
        (final info?, _) => RefreshIndicator(
          onRefresh: () async {
            final info = await _session!.systemInfo();
            if (mounted) setState(() => _info = info);
          },
          child: _Overview(info: info, session: _session!),
        ),
        (_, final error?) => _ErrorState(
          message: describeConnectError(l10n, error),
          onRetry: _connect,
        ),
        _ => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.connecting),
            ],
          ),
        ),
      },
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.info, required this.session});

  final Map<String, dynamic> info;
  final TrueNasSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final memory = info['physmem'];
    final uptime = info['uptime_seconds'];
    final user = session.userInfo?['pw_name'];
    final rows = <(IconData, String, String?)>[
      (Icons.dns_outlined, l10n.infoHostname, info['hostname']?.toString()),
      (Icons.info_outline, l10n.infoVersion, info['version']?.toString()),
      (Icons.api_outlined, l10n.infoApiVersion, session.apiVersion),
      (Icons.memory, l10n.infoModel, info['model']?.toString()),
      (Icons.developer_board, l10n.infoCores, info['cores']?.toString()),
      (
        Icons.storage_outlined,
        l10n.infoMemory,
        memory is num ? formatBytes(memory) : null,
      ),
      (
        Icons.schedule,
        l10n.infoUptime,
        uptime is num
            ? formatDuration(Duration(seconds: uptime.round()))
            : null,
      ),
      (Icons.person_outline, l10n.infoSignedInAs, user?.toString()),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              for (final (icon, label, value) in rows)
                if (value != null && value.isNotEmpty)
                  ListTile(
                    leading: Icon(icon),
                    title: Text(label),
                    subtitle: Text(value),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.serverOverviewNote,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
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

/// `17179869184` → `16.0 GiB`
String formatBytes(num bytes) {
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0 ? '$bytes B' : '${value.toStringAsFixed(1)} ${units[unit]}';
}

/// `Duration(days: 3, hours: 4, minutes: 5)` → `3d 4h 5m`
String formatDuration(Duration duration) {
  final days = duration.inDays;
  final hours = duration.inHours % 24;
  final minutes = duration.inMinutes % 60;
  return [
    if (days > 0) '${days}d',
    if (days > 0 || hours > 0) '${hours}h',
    '${minutes}m',
  ].join(' ');
}
