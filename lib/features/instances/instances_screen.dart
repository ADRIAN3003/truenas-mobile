import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/server_address.dart';
import '../../core/instances/instances_provider.dart';
import '../../core/instances/server_instance.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/dialogs.dart';
import '../../shared/haptics.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../server/server_screen.dart';
import 'server_form_screen.dart';

/// Widest the list grows on tablets, so cards stay readable.
const _maxWidth = 640.0;

void _addServer(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => const ServerFormScreen()),
);

/// Home screen listing saved TrueNAS servers.
class InstancesScreen extends ConsumerWidget {
  const InstancesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final instances = ref.watch(instancesProvider);
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (instances.value?.isNotEmpty ?? false)
            IconButton(
              tooltip: l10n.addServer,
              onPressed: () => _addServer(context),
              icon: const Icon(Icons.add_rounded),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: switch (instances) {
        AsyncData(:final value) when value.isEmpty => const _EmptyState(),
        AsyncData(:final value) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                _Header(count: value.length),
                for (final instance in value) _ServerCard(instance),
                const _AddCard(),
              ],
            ),
          ),
        ),
        AsyncError(:final error) => Center(child: Text(error.toString())),
        _ => const Center(child: CircularProgressIndicator.adaptive()),
      },
    );
  }
}

/// The large title and how many servers there are.
class _Header extends StatelessWidget {
  const _Header({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.serversTitle,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.serversCount(count),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppPalette.of(context).muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// "nas.local" or "192.168.1.10:8443": the address without scheme or slash,
/// which is what tells servers apart and fits on a phone.
String _hostLabel(String url) {
  final uri = ServerAddress.tryParse(url)?.uri;
  if (uri == null) return url;
  return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
}

class _ServerCard extends ConsumerWidget {
  const _ServerCard(this.instance);

  final ServerInstance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final secure = ServerAddress.tryParse(instance.url)?.isSecure ?? true;
    final version = instance.lastApiVersion;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Haptics.selection();
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ServerScreen(instance.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconTile(
                      Icons.dns_rounded,
                      AppPalette.tileBlue,
                      size: 48,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            instance.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _hostLabel(instance.url),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _Menu(instance),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(
                        icon: secure
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        label: secure ? 'HTTPS' : 'HTTP',
                        tone: secure ? StatusTone.neutral : StatusTone.warning,
                      ),
                      if (version != null) _Chip(label: 'API $version'),
                      _Chip(
                        icon: instance.authMethod == AuthMethod.apiKey
                            ? Icons.key_rounded
                            : Icons.person_rounded,
                        label: instance.authMethod == AuthMethod.apiKey
                            ? l10n.authApiKey
                            : l10n.authPassword,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small outlined label under a server's name.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.icon, this.tone = StatusTone.neutral});

  final String label;
  final IconData? icon;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final (color, background) = palette.tone(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// The edit and delete menu of one server.
class _Menu extends ConsumerWidget {
  const _Menu(this.instance);

  final ServerInstance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AppPopupMenu<_Action>(
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
      entries: [
        menuEntry(_Action.edit, l10n.edit),
        menuEntry(_Action.delete, l10n.delete, destructive: true),
      ],
    );
  }
}

enum _Action { edit, delete }

/// A dashed card at the end of the list that adds a server.
class _AddCard extends StatelessWidget {
  const _AddCard();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _addServer(context),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.border, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_rounded, color: primary),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).addServer,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconTile(Icons.dns_rounded, AppPalette.tileBlue, size: 72),
              const SizedBox(height: 20),
              Text(
                l10n.serversEmptyTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.serversEmptyBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppPalette.of(context).muted,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _addServer(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.addServer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
