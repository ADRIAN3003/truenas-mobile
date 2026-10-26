import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/workloads_api.dart';

/// What a home screen shortcut does. The Android counterpart of the Siri and
/// Shortcuts actions: start, stop or restart an app, or run a cloud sync.
enum QuickActionKind {
  appStart,
  appStop,
  appRestart,
  cloudSyncRun;

  /// The app action behind the three app kinds, null for a cloud sync.
  WorkloadAction? get appAction => switch (this) {
    appStart => WorkloadAction.start,
    appStop => WorkloadAction.stop,
    appRestart => WorkloadAction.restart,
    cloudSyncRun => null,
  };

  static QuickActionKind? parse(Object? name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// One thing a shortcut does on one server. [target] is the app's name, or
/// the cloud sync task's id.
@immutable
class QuickAction {
  const QuickAction({
    required this.serverId,
    required this.kind,
    required this.target,
  });

  final String serverId;
  final QuickActionKind kind;
  final String target;

  /// What the phone keeps in the shortcut and hands back when it is tapped.
  Map<String, String> toMap() => {
    'serverId': serverId,
    'kind': kind.name,
    'target': target,
  };

  /// Null when [map] is not a shortcut of this app (damaged or from an older
  /// version), so a bad tap does nothing instead of crashing.
  static QuickAction? fromMap(Object? map) {
    if (map is! Map) return null;
    final kind = QuickActionKind.parse(map['kind']);
    final serverId = map['serverId'];
    final target = map['target'];
    if (kind == null ||
        serverId is! String ||
        serverId.isEmpty ||
        target is! String ||
        target.isEmpty) {
      return null;
    }
    return QuickAction(serverId: serverId, kind: kind, target: target);
  }

  @override
  bool operator ==(Object other) =>
      other is QuickAction &&
      other.serverId == serverId &&
      other.kind == kind &&
      other.target == target;

  @override
  int get hashCode => Object.hash(serverId, kind, target);
}

/// The phone's side of home screen shortcuts.
abstract class QuickActionsPlatform {
  /// Whether the phone's launcher can pin a shortcut.
  Future<bool> canPin();

  /// Asks the launcher to pin a shortcut that does [action], labelled [label].
  /// The launcher may ask the user to confirm. False when it cannot.
  Future<bool> pin(QuickAction action, {required String label});

  /// The shortcut that started the app, if one did. Asked once.
  Future<QuickAction?> launchAction();

  /// Shortcuts tapped while the app is running.
  Stream<QuickAction> get taps;
}

/// For phones without shortcuts (iOS has its own Siri and Shortcuts actions)
/// and for tests.
class NoQuickActions implements QuickActionsPlatform {
  const NoQuickActions();

  @override
  Future<bool> canPin() async => false;

  @override
  Future<bool> pin(QuickAction action, {required String label}) async => false;

  @override
  Future<QuickAction?> launchAction() async => null;

  @override
  Stream<QuickAction> get taps => const Stream.empty();
}

/// Android launcher shortcuts through `MainActivity`.
class PlatformQuickActions implements QuickActionsPlatform {
  PlatformQuickActions() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'action') return;
      final action = QuickAction.fromMap(call.arguments);
      if (action != null) _taps.add(action);
    });
  }

  static const _channel = MethodChannel(
    'hu.adrian.truenasmobile/quick_actions',
  );

  final _taps = StreamController<QuickAction>.broadcast();

  @override
  Future<bool> canPin() async {
    try {
      return await _channel.invokeMethod<bool>('canPin') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> pin(QuickAction action, {required String label}) async {
    try {
      return await _channel.invokeMethod<bool>('pin', {
            ...action.toMap(),
            'label': label,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<QuickAction?> launchAction() async {
    try {
      return QuickAction.fromMap(await _channel.invokeMethod('launchAction'));
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<QuickAction> get taps => _taps.stream;
}

final quickActionsProvider = Provider<QuickActionsPlatform>(
  (ref) => const NoQuickActions(),
);

/// The shortcut the user tapped, until the app has run it. Null when there is
/// none.
class PendingQuickAction extends Notifier<QuickAction?> {
  @override
  QuickAction? build() {
    final sub = ref.watch(quickActionsProvider).taps.listen(run);
    ref.onDispose(sub.cancel);
    return ref.watch(launchQuickActionProvider);
  }

  void run(QuickAction action) => state = action;

  void clear() => state = null;
}

final pendingQuickActionProvider =
    NotifierProvider<PendingQuickAction, QuickAction?>(PendingQuickAction.new);

/// The shortcut that started the app, if one did. `main` reads it from the
/// phone before the first frame.
final launchQuickActionProvider = Provider<QuickAction?>((ref) => null);

/// Whether this phone can pin shortcuts, asked once.
final canPinQuickActionProvider = FutureProvider<bool>(
  (ref) => ref.watch(quickActionsProvider).canPin(),
);
