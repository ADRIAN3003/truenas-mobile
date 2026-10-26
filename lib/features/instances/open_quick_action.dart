import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/instances/instances_provider.dart';
import '../../core/quick_actions/quick_actions.dart';
import '../server/server_screen.dart';

/// Opens the server of a home screen shortcut and runs what it says, whether
/// the app was closed, in the background or open. Wraps the first screen,
/// inside [OpenDefaultServer] so that one steps aside for the tap.
class OpenQuickAction extends ConsumerStatefulWidget {
  const OpenQuickAction({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OpenQuickAction> createState() => _OpenQuickActionState();
}

class _OpenQuickActionState extends ConsumerState<OpenQuickAction> {
  @override
  void initState() {
    super.initState();
    // A tap that started the app is already waiting.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _open(ref.read(pendingQuickActionProvider)),
    );
  }

  Future<void> _open(QuickAction? action) async {
    if (action == null) return;
    ref.read(pendingQuickActionProvider.notifier).clear();
    final servers = await ref.read(instancesProvider.future);
    // The server may have been removed since the shortcut was pinned.
    if (!mounted || !servers.any((s) => s.id == action.serverId)) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ServerScreen(action.serverId, quickAction: action),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingQuickActionProvider, (_, action) => _open(action));
    return widget.child;
  }
}
