import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:truenas_mobile/core/updates/apk_downloader.dart';
import 'package:truenas_mobile/core/updates/release.dart';
import 'package:truenas_mobile/core/updates/update_checker.dart';
import 'package:truenas_mobile/features/updates/apk_installer.dart';

/// A release as GitHub's API lists it.
Map<String, dynamic> releaseJson(
  String tag, {
  String body = 'Notes',
  bool withApks = true,
}) => {
  'tag_name': tag,
  'name': tag,
  'body': body,
  'draft': false,
  'prerelease': false,
  'html_url': 'https://github.com/ADRIAN3003/truenas-mobile/releases/$tag',
  'published_at': '2026-10-16T10:00:00Z',
  'assets': [
    if (withApks) ...[
      for (final abi in ['arm64-v8a', 'armeabi-v7a', 'x86_64'])
        {
          'name': 'truenas-mobile-$tag-$abi-release.apk',
          'size': 100,
          'browser_download_url': 'https://github.com/download/$tag/$abi.apk',
        },
    ],
    {
      'name': 'truenas-mobile-$tag-unsigned.ipa',
      'size': 100,
      'browser_download_url': 'https://github.com/download/$tag/app.ipa',
    },
  ],
};

/// An [UpdateChecker] that answers with [releases], or with [status] when it
/// is not 200. Every request is counted in [requests].
class FakeGitHub {
  FakeGitHub(this.releases, {this.status = 200});

  final List<Map<String, dynamic>> releases;
  final int status;
  var requests = 0;

  UpdateChecker get checker => UpdateChecker(
    client: MockClient((request) async {
      requests++;
      return http.Response(
        jsonEncode(status == 200 ? releases : {'message': 'error'}),
        status,
      );
    }),
  );
}

class FakeApkInstaller implements ApkInstaller {
  var allowed = true;
  var abis = ['arm64-v8a', 'armeabi-v7a'];
  final installed = <String>[];
  var settingsOpened = 0;

  @override
  Future<List<String>> supportedAbis() async => abis;

  @override
  Future<Directory> downloadDirectory() async => Directory('/cache/updates');

  @override
  Future<bool> canInstall() async => allowed;

  @override
  Future<void> openInstallSettings() async => settingsOpened++;

  @override
  Future<void> install(String path) async => installed.add(path);
}

/// Pretends to download: no files, no network.
class FakeApkDownloader implements ApkDownloader {
  final downloaded = <ReleaseAsset>[];
  Object? failWith;

  @override
  Future<File> download(
    ReleaseAsset asset,
    Directory directory, {
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final error = failWith;
    if (error != null) throw error;
    downloaded.add(asset);
    onProgress?.call(50, 100);
    return File('${directory.path}/${asset.name}');
  }

  @override
  Future<void> clear(Directory directory) async {}

  @override
  void close() {}
}
