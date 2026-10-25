import 'package:flutter/material.dart';

import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/widgets.dart';
import '../storage/storage_helpers.dart';

/// Asks before restarting or shutting down [session]'s server, does it, and
/// goes back to the server list since the connection is about to drop.
Future<void> confirmPower(
  BuildContext context,
  TrueNasSession session, {
  required String serverName,
  required bool reboot,
}) async {
  final l10n = AppLocalizations.of(context);
  final navigator = Navigator.of(context);
  final confirmed = await confirmAction(
    context,
    title: reboot
        ? l10n.powerRebootTitle(serverName)
        : l10n.powerShutdownTitle(serverName),
    body: reboot ? l10n.powerRebootBody : l10n.powerShutdownBody,
    confirmLabel: reboot ? l10n.restart : l10n.shutDown,
    cancelLabel: l10n.cancel,
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  final ok = await runWithFeedback(
    context,
    reboot ? session.system.reboot : session.system.shutdown,
    success: reboot
        ? l10n.powerRebooting(serverName)
        : l10n.powerShuttingDown(serverName),
  );
  if (ok) navigator.popUntil((route) => route.isFirst);
}
