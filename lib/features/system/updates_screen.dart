import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/models/system.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/formatting.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/viz_colors.dart';
import '../../shared/widgets.dart';
import '../sharing/sharing_widgets.dart';
import '../storage/storage_helpers.dart';
import '../../shared/dialogs.dart';

typedef _UpdatesData = (String?, UpdateInfo, List<BootEnvironment>);

/// Update status, installing updates, and boot environments.
class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen>
    with LoadState<UpdatesScreen, _UpdatesData> {
  TrueNasSession get _session => widget.session;

  @override
  Future<_UpdatesData> fetch() async {
    final (info, update, envs) = await (
      _session.systemInfo(),
      _session.system.checkForUpdate(),
      _session.system.bootEnvironments(),
    ).wait;
    return (info['version'] as String?, update, envs);
  }

  Future<void> _install(UpdateInfo update) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.updateInstallTitle(update.version ?? ''),
      body: l10n.updateInstallBody,
      confirmLabel: l10n.updateInstall,
      cancelLabel: l10n.cancel,
    );
    if (!confirmed || !mounted) return;
    await runWithFeedback(
      context,
      _session.system.applyUpdate,
      success: l10n.updateStarted,
    );
  }

  Future<void> _bootEnvAction(BootEnvironment env, String action) async {
    final l10n = AppLocalizations.of(context);
    final Future<void> Function() run;
    switch (action) {
      case 'activate':
        final confirmed = await confirmAction(
          context,
          title: l10n.bootEnvActivateTitle(env.id),
          body: l10n.bootEnvActivateBody,
          confirmLabel: l10n.bootEnvActivate,
          cancelLabel: l10n.cancel,
        );
        if (!confirmed) return;
        run = () => _session.system.activateBootEnvironment(env.id);
      case 'keep':
        run = () => _session.system.keepBootEnvironment(env.id, !env.keep);
      default:
        final confirmed = await confirmAction(
          context,
          title: l10n.bootEnvDeleteTitle(env.id),
          body: l10n.bootEnvDeleteBody,
          confirmLabel: l10n.delete,
          cancelLabel: l10n.cancel,
          destructive: true,
        );
        if (!confirmed) return;
        run = () => _session.system.deleteBootEnvironment(env.id);
    }
    if (!mounted) return;
    final ok = await runWithFeedback(
      context,
      run,
      success: l10n.bootEnvChanged,
    );
    if (ok) await load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.updatesTitle)),
      body: AsyncBody<_UpdatesData>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (data) {
          final (version, update, envs) = data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _UpdateCard(
                version: version,
                update: update,
                onInstall: () => _install(update),
              ),
              ...groupedSection(l10n.bootEnvsTitle, indent: 72, [
                for (final env in envs)
                  _BootEnvTile(
                    env: env,
                    onAction: (action) => _bootEnvAction(env, action),
                  ),
              ]),
            ],
          );
        },
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.version,
    required this.update,
    required this.onInstall,
  });

  final String? version;
  final UpdateInfo update;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (icon, color, status) = switch (update) {
      UpdateInfo(error: final error?) => (
        Icons.error_outline,
        VizColors.critical,
        l10n.updateCheckFailed(error),
      ),
      UpdateInfo(rebootRequired: true) => (
        Icons.restart_alt,
        VizColors.warning,
        l10n.updateRebootRequired,
      ),
      UpdateInfo(available: true) => (
        Icons.system_update,
        theme.colorScheme.primary,
        l10n.updateAvailable(update.version ?? ''),
      ),
      _ => (Icons.check_circle, VizColors.good, l10n.updateNone),
    };
    final notes = update.releaseNotesUrl;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (version != null)
              Text(
                l10n.updateCurrent(version!),
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                SoftIcon(icon, statusColors(context, color).$1),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(status, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            if (update.available) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onInstall,
                    icon: const Icon(Icons.download),
                    label: Text(l10n.updateInstall),
                  ),
                  if (notes != null)
                    TextButton.icon(
                      icon: const Icon(Icons.copy),
                      label: Text(l10n.updateReleaseNotes),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await Clipboard.setData(ClipboardData(text: notes));
                        messenger.showSnackBar(
                          SnackBar(content: Text(l10n.apiKeyCopied)),
                        );
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BootEnvTile extends StatelessWidget {
  const _BootEnvTile({required this.env, required this.onAction});

  final BootEnvironment env;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final canDelete = !env.active && !env.activated;
    return ListTile(
      leading: IconTile(
        Icons.history_rounded,
        env.active ? AppPalette.tileGreen : AppPalette.tileSlate,
        size: 40,
      ),
      title: Text(env.id),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              if (env.created case final created?)
                DateFormat.yMMMd(locale).format(created),
              formatBytes(env.usedBytes),
            ].join(' · '),
          ),
          if (env.active || env.activated || env.keep)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 12,
                children: [
                  if (env.active)
                    StatusLabel(
                      icon: Icons.play_circle_outline,
                      color: VizColors.good,
                      label: l10n.bootEnvActive,
                    ),
                  if (env.activated)
                    StatusLabel(
                      icon: Icons.restart_alt,
                      color: muted,
                      label: l10n.bootEnvNextBoot,
                    ),
                  if (env.keep)
                    StatusLabel(
                      icon: Icons.push_pin_outlined,
                      color: muted,
                      label: l10n.bootEnvKept,
                    ),
                ],
              ),
            ),
        ],
      ),
      trailing: AppPopupMenu<String>(
        onSelected: onAction,
        entries: [
          if (!env.activated && env.canActivate)
            menuEntry('activate', l10n.bootEnvActivate),
          menuEntry('keep', env.keep ? l10n.bootEnvUnkeep : l10n.bootEnvKeep),
          if (canDelete) menuEntry('delete', l10n.delete, destructive: true),
        ],
      ),
    );
  }
}
