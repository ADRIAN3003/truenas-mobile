import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/updates/apk_downloader.dart';
import '../../core/updates/app_version.dart';
import '../../core/updates/release.dart';
import '../../core/updates/update_checker.dart';
import 'apk_installer.dart';

final updateCheckerProvider = Provider<UpdateChecker>((ref) {
  final checker = UpdateChecker();
  ref.onDispose(checker.close);
  return checker;
});

final apkDownloaderProvider = Provider<ApkDownloader>((ref) {
  final downloader = ApkDownloader();
  ref.onDispose(downloader.close);
  return downloader;
});

final apkInstallerProvider = Provider<ApkInstaller>(
  (ref) => const PlatformApkInstaller(),
);

/// Whether the app looks for an update by itself when it opens. Off here so
/// tests make no requests; `main` turns it on.
final updateAutoCheckProvider = Provider<bool>((ref) => false);

/// The version of the installed app.
final installedVersionProvider = FutureProvider<AppVersion?>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppVersion.tryParse(info.version);
});

/// What the last look at GitHub found.
class UpdateStatus {
  const UpdateStatus({required this.installed, required this.releases});

  final AppVersion? installed;

  /// Every published release, newest first.
  final List<ReleaseInfo> releases;

  ReleaseInfo? get latest => releases.firstOrNull;

  /// The releases newer than the installed app, newest first.
  List<ReleaseInfo> get newer => [
    for (final release in releases)
      if (installed != null && release.version > installed!) release,
  ];

  bool get updateAvailable => newer.isNotEmpty;
}

final updateStatusProvider =
    AsyncNotifierProvider<UpdateStatusNotifier, UpdateStatus?>(
      UpdateStatusNotifier.new,
    );

/// Looks for releases on GitHub. The state is null until the first check.
class UpdateStatusNotifier extends AsyncNotifier<UpdateStatus?> {
  @override
  UpdateStatus? build() => null;

  Future<void> check() async {
    state = const AsyncLoading<UpdateStatus?>();
    state = await AsyncValue.guard(() async {
      final releases = await ref.read(updateCheckerProvider).releases();
      final installed = await ref.read(installedVersionProvider.future);
      return UpdateStatus(installed: installed, releases: releases);
    });
  }

  /// Looks at the latest release only (one small request), for the check when
  /// the app opens. [UpdateStatus.releases] then holds just that release.
  Future<void> checkLatest() async {
    state = const AsyncLoading<UpdateStatus?>();
    state = await AsyncValue.guard(() async {
      final latest = await ref.read(updateCheckerProvider).latest();
      final installed = await ref.read(installedVersionProvider.future);
      return UpdateStatus(installed: installed, releases: [?latest]);
    });
  }
}

/// Why installing an update from inside the app did not work.
enum ApkFailure {
  /// The user has not allowed this app to install packages yet.
  permission,

  /// The release has no APK for this phone.
  noApk,
  download,
  damaged,

  /// The system installer could not be opened.
  install,
}

enum ApkPhase { idle, downloading, installing }

class ApkState {
  const ApkState({this.phase = ApkPhase.idle, this.progress, this.failure});

  final ApkPhase phase;

  /// 0 to 1 while downloading, null when the size is not known.
  final double? progress;
  final ApkFailure? failure;

  bool get busy => phase != ApkPhase.idle;
}

final apkProvider = NotifierProvider<ApkNotifier, ApkState>(ApkNotifier.new);

/// Downloads a release APK and opens the system installer on it.
class ApkNotifier extends Notifier<ApkState> {
  var _cancelled = false;

  @override
  ApkState build() => const ApkState();

  void cancel() => _cancelled = true;

  /// Leaves a failure behind in [ApkState.failure] (also returned), or null
  /// when the installer was opened.
  Future<ApkFailure?> install(ReleaseInfo release) async {
    if (state.busy) return null;
    _cancelled = false;
    state = const ApkState(phase: ApkPhase.downloading);
    final failure = await _run(release);
    state = failure == null ? const ApkState() : ApkState(failure: failure);
    return failure;
  }

  Future<ApkFailure?> _run(ReleaseInfo release) async {
    final installer = ref.read(apkInstallerProvider);
    try {
      if (!await installer.canInstall()) return ApkFailure.permission;
      final asset = release.apkFor(await installer.supportedAbis());
      if (asset == null) return ApkFailure.noApk;
      final directory = await installer.downloadDirectory();
      final downloader = ref.read(apkDownloaderProvider);
      // Old downloads are not needed any more.
      await downloader.clear(directory);
      final file = await downloader.download(
        asset,
        directory,
        isCancelled: () => _cancelled,
        onProgress: (received, total) {
          state = ApkState(
            phase: ApkPhase.downloading,
            progress: total == null || total <= 0 ? null : received / total,
          );
        },
      );
      state = const ApkState(phase: ApkPhase.installing);
      await installer.install(file.path);
      return null;
    } on ApkDownloadException catch (e) {
      return switch (e.failure) {
        ApkDownloadFailure.cancelled => null,
        ApkDownloadFailure.damaged => ApkFailure.damaged,
        ApkDownloadFailure.network => ApkFailure.download,
      };
    } on PlatformException {
      return ApkFailure.install;
    }
  }
}
