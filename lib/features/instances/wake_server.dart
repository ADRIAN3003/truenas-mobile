import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/instances/server_instance.dart';
import '../../core/logging/app_log.dart';
import '../../core/wol/wake_on_lan.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/haptics.dart';

/// Sends the magic packet of [instance] and says in a snackbar how it went.
/// Does nothing for a server without Wake-on-LAN settings.
Future<void> wakeServer(
  BuildContext context,
  WidgetRef ref,
  ServerInstance instance,
) async {
  final settings = instance.wol;
  if (settings == null) return;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  Haptics.confirm();
  try {
    await ref.read(wakeOnLanSenderProvider).wake(settings);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.wolSent(instance.name))),
    );
  } catch (error) {
    Haptics.warning();
    AppLog.instance.warning('wake-on-lan', '${instance.name}: $error');
    messenger.showSnackBar(SnackBar(content: Text(l10n.wolFailed('$error'))));
  }
}
