import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/instances/default_server.dart';
import '../../core/instances/instances_provider.dart';
import '../../core/notifications/alert_taps.dart';
import '../../core/quick_actions/quick_actions.dart';
import '../../core/settings/settings_provider.dart';
import '../server/server_screen.dart';

/// Whether the app opens its default server by itself at start. Off unless
/// `main` turns it on, so widget tests that pump the app stay on the list.
final openDefaultServerProvider = Provider<bool>((ref) => false);

/// Opens the default server on top of the server list once, when the app
/// starts, so going back lands on the list. Wraps the first screen.
class OpenDefaultServer extends ConsumerStatefulWidget {
  const OpenDefaultServer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OpenDefaultServer> createState() => _OpenDefaultServerState();
}

class _OpenDefaultServerState extends ConsumerState<OpenDefaultServer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (!ref.read(openDefaultServerProvider)) return;
    // A tapped alert notification opens its own server instead.
    if (ref.read(pendingAlertServerProvider) != null) return;
    // So does a tapped shortcut.
    if (ref.read(pendingQuickActionProvider) != null) return;
    final servers = await ref.read(instancesProvider.future);
    if (!mounted) return;
    final server = defaultServer(
      servers,
      ref.read(settingsProvider).defaultServerId,
    );
    if (server == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ServerScreen(server.id)),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
