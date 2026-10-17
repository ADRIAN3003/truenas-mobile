import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/biometric_auth.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme.dart';

/// Keeps the app behind the phone's own unlock (Face ID, a fingerprint or the
/// passcode) while the app lock setting is on: at start, and each time the app
/// returns from the background. It sits above the navigator, so every screen
/// and dialog is covered, and it leaves the app underneath alive, so an open
/// server or shell is still there after unlocking.
///
/// While the app is not in front (the app switcher, a notification pulled
/// down) the lock screen is shown as a cover as well, so the phone's snapshot
/// of the app does not show a server.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  late bool _locked;
  bool _covered = false;
  bool _authenticating = false;
  bool _failed = false;

  bool get _enabled => ref.read(settingsProvider).appLock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = _enabled;
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled) return;
    switch (state) {
      case AppLifecycleState.resumed:
        setState(() => _covered = false);
        if (_locked) _unlock();
      case AppLifecycleState.inactive:
        setState(() => _covered = true);
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Left the app: it asks again on the way back.
        setState(() {
          _covered = true;
          _locked = true;
        });
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || !mounted) return;
    final auth = ref.read(biometricAuthProvider);
    // A phone with neither a biometric nor a passcode cannot ask: there is
    // nothing to lock with, so do not lock the user out.
    if (!await auth.isAvailable()) {
      if (mounted) setState(() => _locked = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _authenticating = true;
      _failed = false;
    });
    final reason = AppLocalizations.of(context).appLockReason;
    final ok = await auth.authenticate(reason);
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      if (ok) {
        _locked = false;
      } else {
        _failed = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Turning the lock on or off inside the app never locks that session.
    ref.listen(settingsProvider.select((s) => s.appLock), (_, on) {
      if (!on) setState(() => _locked = false);
    });
    final enabled = ref.watch(settingsProvider.select((s) => s.appLock));
    final showing = enabled && (_locked || _covered);
    return Stack(
      children: [
        ExcludeSemantics(excluding: showing, child: widget.child),
        if (showing)
          Positioned.fill(
            child: LockScreen(
              failed: _failed && !_authenticating,
              busy: _authenticating,
              onUnlock: _unlock,
            ),
          ),
      ],
    );
  }
}

/// What is shown instead of the app while it is locked.
class LockScreen extends ConsumerWidget {
  const LockScreen({
    required this.failed,
    required this.busy,
    required this.onUnlock,
    super.key,
  });

  /// The last try was cancelled or did not match.
  final bool failed;

  /// The system prompt is up.
  final bool busy;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final theme = Theme.of(context);
    final kind = ref.watch(biometricKindProvider).value ?? BiometricKind.other;
    return Material(
      color: palette.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.appLockTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                if (failed) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.appLockFailed,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: busy ? null : onUnlock,
                  icon: Icon(switch (kind) {
                    BiometricKind.face => Icons.face_unlock_rounded,
                    BiometricKind.fingerprint => Icons.fingerprint_rounded,
                    BiometricKind.other => Icons.lock_open_rounded,
                  }),
                  label: Text(l10n.appLockUnlock),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
