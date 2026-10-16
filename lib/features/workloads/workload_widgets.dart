import 'package:flutter/material.dart';

import '../../core/api/workloads_api.dart';
import '../../core/models/workloads.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/connect_dialogs.dart';
import '../../shared/viz_colors.dart';
import '../../shared/widgets.dart';
import '../shell/shell_screen.dart';
import '../storage/storage_helpers.dart';
import '../../shared/dialogs.dart';

/// State label with icon and colour, for apps, VMs and containers.
class WorkloadStateLabel extends StatelessWidget {
  const WorkloadStateLabel({super.key, required this.state});

  final WorkloadState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final (icon, color, label) = switch (state) {
      WorkloadState.running => (
        Icons.check_circle,
        VizColors.good,
        l10n.stateRunning,
      ),
      WorkloadState.stopped => (
        Icons.stop_circle_outlined,
        muted,
        l10n.stateStopped,
      ),
      WorkloadState.deploying => (
        Icons.hourglass_top,
        VizColors.warning,
        l10n.stateDeploying,
      ),
      WorkloadState.stopping => (
        Icons.hourglass_bottom,
        VizColors.warning,
        l10n.stateStopping,
      ),
      WorkloadState.suspended => (
        Icons.pause_circle_outline,
        VizColors.warning,
        l10n.stateSuspended,
      ),
      WorkloadState.crashed => (
        Icons.error,
        VizColors.critical,
        l10n.stateCrashed,
      ),
      WorkloadState.unknown => (Icons.help_outline, muted, l10n.stateUnknown),
    };
    return StatusLabel(icon: icon, color: color, label: label);
  }
}

/// The actions to offer for a workload in [state].
List<WorkloadAction> actionsFor(
  WorkloadState state, {
  required List<WorkloadAction> supported,
}) {
  final up = state.isUp || state == WorkloadState.suspended;
  return [
    for (final action in supported)
      if (switch (action) {
        WorkloadAction.start => !up,
        WorkloadAction.stop ||
        WorkloadAction.restart ||
        WorkloadAction.powerOff => up,
        WorkloadAction.upgrade || WorkloadAction.delete => true,
      })
        action,
  ];
}

String actionLabel(AppLocalizations l10n, WorkloadAction action) =>
    switch (action) {
      WorkloadAction.start => l10n.actionStart,
      WorkloadAction.stop => l10n.actionStop,
      WorkloadAction.restart => l10n.actionRestart,
      WorkloadAction.powerOff => l10n.actionPowerOff,
      WorkloadAction.upgrade => l10n.actionUpgrade,
      WorkloadAction.delete => l10n.actionDelete,
    };

/// Confirms [action] on the workload called [name] where it needs it, runs
/// it with a snackbar, and returns whether it ran successfully.
/// [onConfirmed] is called once the user has agreed, before it runs.
Future<bool> runWorkloadAction(
  BuildContext context, {
  required String name,
  required WorkloadAction action,
  required Future<void> Function() run,
  bool isVm = false,
  String? upgradeFrom,
  String? upgradeTo,
  VoidCallback? onConfirmed,
}) async {
  final l10n = AppLocalizations.of(context);
  final Future<bool> Function()? ask = switch (action) {
    WorkloadAction.start => null,
    WorkloadAction.stop => () => confirmAction(
      context,
      title: l10n.stopTitle(name),
      body: isVm ? l10n.vmStopBody : l10n.stopBody,
      confirmLabel: l10n.actionStop,
      cancelLabel: l10n.cancel,
    ),
    WorkloadAction.restart => () => confirmAction(
      context,
      title: l10n.restartTitle(name),
      body: l10n.restartBody,
      confirmLabel: l10n.actionRestart,
      cancelLabel: l10n.cancel,
    ),
    WorkloadAction.powerOff => () => confirmAction(
      context,
      title: l10n.vmPowerOffTitle(name),
      body: l10n.vmPowerOffBody,
      confirmLabel: l10n.actionPowerOff,
      cancelLabel: l10n.cancel,
      destructive: true,
    ),
    WorkloadAction.upgrade => () => confirmAction(
      context,
      title: l10n.appUpgradeTitle(name),
      body: l10n.appUpgradeBody(name, upgradeFrom ?? '', upgradeTo ?? ''),
      confirmLabel: l10n.actionUpgrade,
      cancelLabel: l10n.cancel,
    ),
    WorkloadAction.delete => () => confirmAction(
      context,
      title: l10n.appDeleteTitle(name),
      body: l10n.appDeleteBody,
      confirmLabel: l10n.actionDelete,
      cancelLabel: l10n.cancel,
      typeToConfirm: name,
      typeToConfirmHint: l10n.typeNameToConfirm(name),
      destructive: true,
    ),
  };
  final confirmed = ask == null || await ask();
  if (!confirmed || !context.mounted) return false;
  onConfirmed?.call();
  return runWithFeedback(
    context,
    run,
    success: switch (action) {
      WorkloadAction.start => l10n.actionStarted(name),
      WorkloadAction.stop => l10n.actionStopped(name),
      WorkloadAction.restart => l10n.actionRestarted(name),
      WorkloadAction.powerOff => l10n.actionPoweredOff(name),
      WorkloadAction.upgrade => l10n.actionUpgraded(name),
      WorkloadAction.delete => l10n.actionDeleted(name),
    },
  );
}

/// A popup menu of [actions], or a spinner while [busy].
class WorkloadMenu extends StatelessWidget {
  const WorkloadMenu({
    super.key,
    required this.actions,
    required this.busy,
    required this.onSelected,
    this.onShell,
  });

  final List<WorkloadAction> actions;
  final bool busy;
  final ValueChanged<WorkloadAction> onSelected;

  /// Adds a Shell entry when set.
  final VoidCallback? onShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (busy) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        ),
      );
    }
    final onShell = this.onShell;
    return AppPopupMenu<Object>(
      enabled: actions.isNotEmpty || onShell != null,
      onSelected: (value) =>
          value is WorkloadAction ? onSelected(value) : onShell?.call(),
      entries: [
        if (onShell != null) menuEntry<Object>('shell', l10n.shellTitle),
        for (final action in actions)
          menuEntry<Object>(action, actionLabel(l10n, action)),
      ],
    );
  }
}

/// Opens a shell with [options] (a VM console, app or container shell).
/// [fallbackCommands] are tried in turn when the server's default shell is
/// not in the image.
Future<void> openShell(
  BuildContext context,
  TrueNasSession session,
  Map<String, Object?> options,
  String title, {
  List<String> fallbackCommands = const [],
}) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    builder: (_) => ShellScreen(
      session: session,
      options: options,
      title: title,
      fallbackCommands: fallbackCommands,
    ),
  ),
);

/// Opens a shell in one of [app]'s containers, asking which when it has
/// several.
Future<void> openAppShell(
  BuildContext context,
  TrueNasSession session,
  String app,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final Map<String, String> containers;
  try {
    containers = await session.workloads.appShellContainers(app);
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(describeConnectError(l10n, error))),
    );
    return;
  }
  if (!context.mounted) return;
  if (containers.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.shellNoContainers)));
    return;
  }
  final id = containers.length == 1
      ? containers.keys.single
      : await showAppDialog<String>(
          context: context,
          builder: (context) => AppDialog(
            scrollable: true,
            title: Text(l10n.shellPickContainer),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final MapEntry(:key, :value) in containers.entries)
                  ListTile(
                    dense: true,
                    title: Text(value),
                    onTap: () => Navigator.pop(context, key),
                  ),
              ],
            ),
          ),
        );
  if (id == null || !context.mounted) return;
  await openShell(
    context,
    session,
    WorkloadsApi.appShell(app, id),
    '$app · ${containers[id]}',
    fallbackCommands: WorkloadsApi.shellFallbacks,
  );
}
