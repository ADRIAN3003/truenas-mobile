import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_provider.dart';
import '../../core/updates/release.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/dialogs.dart';
import 'update_screen.dart';
import 'updates_provider.dart';

/// Looks for a newer release once, when the app opens, and offers it in a
/// dialog: view it, skip that version, or decide later. Wraps the first
/// screen, so a dialog has a navigator to open on.
class UpdateAutoCheck extends ConsumerStatefulWidget {
  const UpdateAutoCheck({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateAutoCheck> createState() => _UpdateAutoCheckState();
}

enum _Choice { view, skip, later }

class _UpdateAutoCheckState extends ConsumerState<UpdateAutoCheck> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (!ref.read(updateAutoCheckProvider)) return;
    if (!ref.read(settingsProvider).checkForUpdates) return;
    // A failed check is not worth bothering anyone about; the update screen
    // shows failures when the user asks.
    await ref.read(updateStatusProvider.notifier).check();
    if (!mounted) return;
    final status = ref.read(updateStatusProvider).value;
    final latest = status?.latest;
    if (status == null || latest == null || !status.updateAvailable) return;
    if (ref.read(settingsProvider).skippedVersion ==
        latest.version.toString()) {
      return;
    }
    await _offer(latest, status.installed.toString());
  }

  Future<void> _offer(ReleaseInfo latest, String installed) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showAppDialog<_Choice>(
      context: context,
      builder: (context) => AppDialog(
        title: Text(l10n.appUpdatePromptTitle),
        content: Text(
          l10n.appUpdatePromptBody(latest.version.toString(), installed),
        ),
        actions: [
          dialogAction(
            context,
            label: l10n.appUpdateSkip,
            onPressed: () => Navigator.pop(context, _Choice.skip),
          ),
          dialogAction(
            context,
            label: l10n.appUpdateLater,
            onPressed: () => Navigator.pop(context, _Choice.later),
          ),
          dialogAction(
            context,
            label: l10n.appUpdateViewUpdate,
            primary: true,
            onPressed: () => Navigator.pop(context, _Choice.view),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case _Choice.skip:
        await ref
            .read(settingsProvider.notifier)
            .update(
              (s) =>
                  s.copyWith(skippedVersion: () => latest.version.toString()),
            );
      case _Choice.view:
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const UpdateScreen()),
        );
      case _Choice.later || null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
