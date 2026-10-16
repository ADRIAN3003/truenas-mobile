import 'dart:io';

import 'package:flutter/services.dart';

/// What the app needs from Android to install an update it downloaded. The
/// real one talks to `MainActivity`; tests use a fake.
abstract interface class ApkInstaller {
  /// The phone's CPU ABIs, best first (`arm64-v8a`, `armeabi-v7a`, ...).
  Future<List<String>> supportedAbis();

  /// A folder the installer may read from, which the app also writes to.
  Future<Directory> downloadDirectory();

  /// Whether the user allowed this app to install packages. Android asks for
  /// that once, per app, in its settings.
  Future<bool> canInstall();

  /// Opens the system page where the user can allow installing from this app.
  Future<void> openInstallSettings();

  /// Opens the system installer on the APK at [path].
  Future<void> install(String path);
}

class PlatformApkInstaller implements ApkInstaller {
  const PlatformApkInstaller();

  static const _channel = MethodChannel('hu.adrian.truenasmobile/installer');

  @override
  Future<List<String>> supportedAbis() async => [
    ...?await _channel.invokeListMethod<String>('abis'),
  ];

  @override
  Future<Directory> downloadDirectory() async =>
      Directory((await _channel.invokeMethod<String>('downloadDirectory'))!);

  @override
  Future<bool> canInstall() async =>
      await _channel.invokeMethod<bool>('canInstall') ?? false;

  @override
  Future<void> openInstallSettings() =>
      _channel.invokeMethod<void>('openInstallSettings');

  @override
  Future<void> install(String path) =>
      _channel.invokeMethod<void>('install', {'path': path});
}
