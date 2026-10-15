import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/instances/instances_provider.dart';
import '../../core/instances/server_instance.dart';
import '../../l10n/generated/app_localizations.dart';
import '../server/server_screen.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import 'server_form_screen.dart';

/// Home screen listing saved TrueNAS servers.
class InstancesScreen extends ConsumerWidget {
  const InstancesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final instances = ref.watch(instancesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.serversTitle)),
      body: switch (instances) {
        AsyncData(:final value) when value.isEmpty => const _EmptyState(),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            GroupedCard(children: [for (final i in value) _ServerTile(i)]),
          ],
        ),
        AsyncError(:final error) => Center(child: Text(error.toString())),
        _ => const Center(child: CircularProgressIndicator.adaptive()),
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const ServerFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.addServer),
      ),
    );
  }
}

class _ServerTile extends ConsumerWidget {
  const _ServerTile(this.instance);

  final ServerInstance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final subtitle = [
      instance.url,
      if (instance.lastApiVersion != null) 'API ${instance.lastApiVersion}',
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      leading: const IconTile(Icons.dns_rounded, AppPalette.tileBlue, size: 40),
      title: Text(instance.name),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => ServerScreen(instance.id)),
      ),
      trailing: PopupMenuButton<_Action>(
        onSelected: (action) async {
          switch (action) {
            case _Action.edit:
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ServerFormScreen(instance: instance),
                ),
              );
            case _Action.delete:
              final confirmed = await confirmAction(
                context,
                title: l10n.deleteServerTitle(instance.name),
                body: l10n.deleteServerBody,
                confirmLabel: l10n.delete,
                cancelLabel: l10n.cancel,
                destructive: true,
              );
              if (confirmed) {
                await ref.read(instancesProvider.notifier).remove(instance.id);
              }
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: _Action.edit, child: Text(l10n.edit)),
          PopupMenuItem(value: _Action.delete, child: Text(l10n.delete)),
        ],
      ),
    );
  }
}

enum _Action { edit, delete }

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconTile(Icons.dns_rounded, AppPalette.tileBlue, size: 72),
            const SizedBox(height: 16),
            Text(l10n.serversEmptyTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              l10n.serversEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
