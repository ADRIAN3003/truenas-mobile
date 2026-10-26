import 'dart:async';

import 'package:truenas_mobile/core/quick_actions/quick_actions.dart';

/// The launcher's shortcuts, without a phone.
class FakeQuickActions implements QuickActionsPlatform {
  FakeQuickActions({this.canPinShortcuts = true, this.launch});

  /// Whether the launcher can pin shortcuts.
  bool canPinShortcuts;

  /// The shortcut that started the app, if any.
  final QuickAction? launch;

  /// Every shortcut pinned, with its label.
  final pinned = <(QuickAction, String)>[];

  final _taps = StreamController<QuickAction>.broadcast();

  /// Taps a shortcut while the app is open.
  void tap(QuickAction action) => _taps.add(action);

  @override
  Future<bool> canPin() async => canPinShortcuts;

  @override
  Future<bool> pin(QuickAction action, {required String label}) async {
    if (!canPinShortcuts) return false;
    pinned.add((action, label));
    return true;
  }

  @override
  Future<QuickAction?> launchAction() async => launch;

  @override
  Stream<QuickAction> get taps => _taps.stream;
}
