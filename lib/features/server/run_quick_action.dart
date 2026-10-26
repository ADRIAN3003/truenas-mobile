import 'package:flutter/material.dart';

import '../../core/models/protection.dart';
import '../../core/quick_actions/quick_actions.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../storage/storage_helpers.dart';
import '../workloads/workload_widgets.dart';

/// Does what a home screen shortcut says on the open server, asking first
/// where the same action in the app would (stop, restart). Like those, it
/// only starts the work and tells how it went in a snackbar.
Future<void> runQuickAction(
  BuildContext context,
  TrueNasSession session,
  QuickAction action,
) async {
  if (action.kind.appAction case final appAction?) {
    await runWorkloadAction(
      context,
      name: action.target,
      action: appAction,
      run: () => session.workloads.appAction(action.target, appAction),
    );
    return;
  }
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  ProtectionTask? task;
  final ok = await runWithFeedback(context, () async {
    final tasks = await session.protection.tasks(ProtectionKind.cloudSync);
    task = tasks.where((t) => '${t.id}' == action.target).firstOrNull;
    if (task != null) await session.protection.runNow(task!);
  });
  if (!ok) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        task == null ? l10n.shortcutTaskMissing : l10n.taskStarted(task!.name),
      ),
    ),
  );
}
