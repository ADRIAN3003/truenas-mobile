import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tracked_job.dart';

/// Where a job is, as the lock screen shows it.
enum LiveStatus { waiting, running, done, failed, aborted, stale }

/// What one job's Live Activity (iOS) or ongoing notification (Android) shows.
class LiveProgressUpdate {
  const LiveProgressUpdate({
    required this.id,
    required this.kind,
    required this.title,
    required this.server,
    required this.detail,
    required this.progress,
    required this.status,
    required this.statusLabel,
    required this.staleLabel,
    required this.startedAt,
    required this.channelName,
    required this.channelDescription,
  });

  /// Stays the same for the life of the job.
  final String id;
  final JobKind kind;
  final String title;
  final String server;

  /// What the job is doing right now, or why it failed.
  final String detail;

  /// 0 to 1, or null when the server does not say how far along it is.
  final double? progress;
  final LiveStatus status;
  final String statusLabel;

  /// Shown when the phone sees no news of the job for a while.
  final String staleLabel;
  final DateTime startedAt;

  /// The Android notification channel's name and description.
  final String channelName;
  final String channelDescription;

  bool get isFinal => switch (status) {
    LiveStatus.done || LiveStatus.failed || LiveStatus.aborted => true,
    _ => false,
  };

  Map<String, Object?> toMap() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'server': server,
    'detail': detail,
    'progress': progress,
    'status': status.name,
    'statusLabel': statusLabel,
    'staleLabel': staleLabel,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'channelName': channelName,
    'channelDescription': channelDescription,
  };
}

/// Why running jobs can or cannot be shown outside the app.
enum LiveSupport {
  /// They can.
  ok,

  /// This platform has nothing to show them with.
  unavailable,

  /// The user turned Live Activities off for the app (iOS Settings).
  disabled,

  /// The build has no widget extension to draw them: a sideloading tool
  /// removed it. The Dynamic Island would stay empty.
  noExtension,
}

/// Shows running jobs outside the app: a Live Activity on the iPhone lock
/// screen and Dynamic Island, an ongoing progress notification on Android.
///
/// Nothing pushes to them while the app is not running, so they only move
/// while the app is open or lives on in the background. When updates stop
/// the activity turns stale on iOS and says so on Android.
abstract interface class LiveProgress {
  /// Whether this phone and its settings allow it at all.
  Future<bool> isSupported();

  /// Whether it works, or why it does not.
  Future<LiveSupport> support();

  /// Asks for the notification permission where the phone needs it (Android
  /// 13 and newer). True when jobs may be shown.
  Future<bool> requestPermission();

  /// Starts or updates the activity of [update.id]. A final status leaves
  /// the result on the lock screen for a while.
  Future<void> show(LiveProgressUpdate update);

  /// Removes the activity of [id] at once.
  Future<void> end(String id);

  /// Removes every activity except [keep]: those left by an earlier run.
  Future<void> endAllExcept(Set<String> keep);
}

/// For platforms without any of this, and as the default in tests.
class NoLiveProgress implements LiveProgress {
  const NoLiveProgress();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<LiveSupport> support() async => LiveSupport.unavailable;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> show(LiveProgressUpdate update) async {}

  @override
  Future<void> end(String id) async {}

  @override
  Future<void> endAllExcept(Set<String> keep) async {}
}

/// Talks to ActivityKit on iOS and the notification manager on Android over
/// a method channel.
class PlatformLiveProgress implements LiveProgress {
  const PlatformLiveProgress();

  static const _channel = MethodChannel(
    'hu.adrian.truenasmobile/live_progress',
  );

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      // The phone refused (activities turned off, notifications blocked).
      return null;
    }
  }

  @override
  Future<bool> isSupported() async =>
      await _invoke<bool>('isSupported') ?? false;

  @override
  Future<LiveSupport> support() async {
    // Android has no extension to lose; there, supported means allowed.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return switch (await _invoke<String>('status')) {
        'ok' => LiveSupport.ok,
        'disabled' => LiveSupport.disabled,
        'noExtension' => LiveSupport.noExtension,
        _ => LiveSupport.unavailable,
      };
    }
    return await isSupported() ? LiveSupport.ok : LiveSupport.unavailable;
  }

  @override
  Future<bool> requestPermission() async =>
      await _invoke<bool>('requestPermission') ?? false;

  @override
  Future<void> show(LiveProgressUpdate update) =>
      _invoke<void>('show', update.toMap());

  @override
  Future<void> end(String id) => _invoke<void>('end', {'id': id});

  @override
  Future<void> endAllExcept(Set<String> keep) =>
      _invoke<void>('endAllExcept', {'keep': keep.toList()});
}

final liveProgressProvider = Provider<LiveProgress>(
  (ref) => const NoLiveProgress(),
);

/// What the settings screen says under the live job progress switch.
final liveSupportProvider = FutureProvider<LiveSupport>(
  (ref) => ref.watch(liveProgressProvider).support(),
);
