import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/protection.dart';
import '../../core/quick_actions/quick_actions.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/dialogs.dart';

/// Whether this phone can pin home screen shortcuts, so screens show their
/// "Add to home screen" entry only where it works.
bool canAddShortcut(WidgetRef ref) =>
    ref.watch(canPinQuickActionProvider).value ?? false;

Future<void> _pin(
  BuildContext context,
  WidgetRef ref,
  QuickAction action,
  String label,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final pinned = await ref.read(quickActionsProvider).pin(action, label: label);
  // The launcher asks the user to confirm and says so itself.
  if (!pinned) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.shortcutUnsupported)));
  }
}

/// Asks what a shortcut for the app [name] should do, then asks the launcher
/// to pin it.
Future<void> addAppShortcut(
  BuildContext context,
  WidgetRef ref,
  TrueNasSession session,
  String name,
) async {
  final serverId = session.instanceId;
  if (serverId == null) return;
  final l10n = AppLocalizations.of(context);
  final labels = {
    QuickActionKind.appStart: l10n.shortcutLabelStart(name),
    QuickActionKind.appStop: l10n.shortcutLabelStop(name),
    QuickActionKind.appRestart: l10n.shortcutLabelRestart(name),
  };
  final choice = await showAppChoice<QuickActionKind>(
    context: context,
    title: l10n.shortcutPickTitle(name),
    choices: [
      appChoice(
        QuickActionKind.appStart,
        labels[QuickActionKind.appStart]!,
        leading: const Icon(Icons.play_arrow_rounded),
      ),
      appChoice(
        QuickActionKind.appStop,
        labels[QuickActionKind.appStop]!,
        leading: const Icon(Icons.stop_rounded),
      ),
      appChoice(
        QuickActionKind.appRestart,
        labels[QuickActionKind.appRestart]!,
        leading: const Icon(Icons.restart_alt_rounded),
      ),
    ],
  );
  if (choice == null || !context.mounted) return;
  final kind = choice.$1;
  await _pin(
    context,
    ref,
    QuickAction(serverId: serverId, kind: kind, target: name),
    labels[kind]!,
  );
}

/// Asks the launcher to pin a shortcut that syncs the cloud sync [task] now.
Future<void> addCloudSyncShortcut(
  BuildContext context,
  WidgetRef ref,
  TrueNasSession session,
  ProtectionTask task,
) async {
  final serverId = session.instanceId;
  if (serverId == null) return;
  await _pin(
    context,
    ref,
    QuickAction(
      serverId: serverId,
      kind: QuickActionKind.cloudSyncRun,
      target: '${task.id}',
    ),
    AppLocalizations.of(context).shortcutLabelSync(task.name),
  );
}
