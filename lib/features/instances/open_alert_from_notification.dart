import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/instances/instances_provider.dart';
import '../../core/notifications/alert_taps.dart';
import '../server/server_screen.dart';

/// Opens a server's alerts when the user taps one of its alert notifications,
/// whether the app was closed, in the background or open. Wraps the first
/// screen, inside [OpenDefaultServer] so that one steps aside for the tap.
class OpenAlertFromNotification extends ConsumerStatefulWidget {
  const OpenAlertFromNotification({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OpenAlertFromNotification> createState() =>
      _OpenAlertFromNotificationState();
}

class _OpenAlertFromNotificationState
    extends ConsumerState<OpenAlertFromNotification> {
  @override
  void initState() {
    super.initState();
    // A tap that started the app is already waiting.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _open(ref.read(pendingAlertServerProvider)),
    );
  }

  Future<void> _open(String? serverId) async {
    if (serverId == null) return;
    ref.read(pendingAlertServerProvider.notifier).clear();
    final servers = await ref.read(instancesProvider.future);
    // The server may have been removed since the notification was shown.
    if (!mounted || !servers.any((s) => s.id == serverId)) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ServerScreen(serverId, openAlertsOnStart: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingAlertServerProvider, (_, serverId) => _open(serverId));
    return widget.child;
  }
}
