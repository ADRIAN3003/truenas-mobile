import 'package:flutter/material.dart';

import '../../core/api/sharing_api.dart';
import '../../core/models/sharing.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/viz_colors.dart';
import '../../shared/widgets.dart';
import '../storage/storage_helpers.dart';

/// Running / stopped label for a service.
class ServiceStateLabel extends StatelessWidget {
  const ServiceStateLabel({super.key, required this.service});

  final ServiceEntry service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return service.running
        ? StatusLabel(
            icon: Icons.check_circle,
            color: VizColors.good,
            label: l10n.serviceRunning,
          )
        : StatusLabel(
            icon: Icons.stop_circle_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            label: l10n.serviceStopped,
          );
  }
}

/// Warns that [service] is stopped and offers to start it.
class ServiceStoppedBanner extends StatelessWidget {
  const ServiceStoppedBanner({
    super.key,
    required this.service,
    required this.onStart,
  });

  final ServiceEntry service;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber, color: VizColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l10n.serviceNotRunning(service.displayName)),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onStart,
                child: Text(l10n.serviceStart),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Starts [service] with feedback; returns whether it worked.
Future<bool> startService(
  BuildContext context,
  TrueNasSession session,
  ServiceEntry service,
) {
  final l10n = AppLocalizations.of(context);
  return runWithFeedback(
    context,
    () => session.sharing.controlService(service.service, ServiceAction.start),
    success: l10n.serviceStartedMessage(service.displayName),
  );
}

/// Mount points of every unlocked filesystem dataset, for share pickers.
Future<List<String>> shareablePaths(TrueNasSession session) async {
  final pools = await session.storage.pools();
  final paths = <String>[];
  for (final pool in pools) {
    for (final dataset in await session.storage.datasets(pool.name)) {
      final mountpoint = dataset.mountpoint;
      if (!dataset.isVolume && !dataset.locked && mountpoint != null) {
        paths.add(mountpoint);
      }
    }
  }
  return paths;
}

/// A dropdown of [paths] for choosing a share's folder.
class SharePathField extends StatelessWidget {
  const SharePathField({
    super.key,
    required this.paths,
    required this.value,
    required this.onChanged,
  });

  final List<String> paths;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.sharePath),
      items: [
        for (final p in paths)
          DropdownMenuItem(
            value: p,
            child: Text(p, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (p) {
        if (p != null) onChanged(p);
      },
    );
  }
}

/// Small loading / error / content wrapper for screens that load once.
mixin LoadState<W extends StatefulWidget, T> on State<W> {
  T? data;
  Object? error;

  Future<T> fetch();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await fetch();
      if (!mounted) return;
      setState(() {
        data = value;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }
}
