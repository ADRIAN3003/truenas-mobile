import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/instances/instances_provider.dart';
import '../../core/instances/server_instance.dart';
import '../../l10n/generated/app_localizations.dart';
import '../server/server_screen.dart';
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
        AsyncData(:final value) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: value.length,
          itemBuilder: (context, index) => _ServerTile(value[index]),
        ),
        AsyncError(:final error) => Center(child: Text(error.toString())),
        _ => const Center(child: CircularProgressIndicator()),
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
    final theme = Theme.of(context);
    final subtitle = [
      instance.url,
      if (instance.lastApiVersion != null) 'API ${instance.lastApiVersion}',
    ].join(' · ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: const Icon(Icons.dns_outlined),
      ),
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
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.deleteServerTitle(instance.name)),
                  content: Text(l10n.deleteServerBody),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l10n.delete),
                    ),
                  ],
                ),
              );
              if (confirmed ?? false) {
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
            Icon(
              Icons.dns_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),
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
