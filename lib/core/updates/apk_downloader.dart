import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'release.dart';

/// Why an APK could not be downloaded.
enum ApkDownloadFailure {
  /// The server could not be reached, answered with an error or dropped the
  /// connection.
  network,

  /// The file is not the size or checksum GitHub lists for it.
  damaged,

  /// The user cancelled.
  cancelled,
}

class ApkDownloadException implements Exception {
  const ApkDownloadException(this.failure);

  final ApkDownloadFailure failure;

  @override
  String toString() => 'ApkDownloadException($failure)';
}

/// Downloads a release APK to disk and checks it.
class ApkDownloader {
  ApkDownloader({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Saves [asset] in [directory] and returns the file. [onProgress] gets the
  /// bytes so far and the total, when the server says it. [isCancelled] is
  /// asked between chunks. The file only gets its final name once it is
  /// complete and matches the size and SHA-256 GitHub lists, so a half
  /// download is never handed to the installer.
  Future<File> download(
    ReleaseAsset asset,
    Directory directory, {
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final target = File('${directory.path}/${asset.name}');
    final partial = File('${target.path}.part');
    await directory.create(recursive: true);
    IOSink? sink;
    try {
      final response = await _client.send(
        http.Request('GET', Uri.parse(asset.url)),
      );
      if (response.statusCode != 200) {
        throw const ApkDownloadException(ApkDownloadFailure.network);
      }
      final total = response.contentLength ?? asset.size;
      sink = partial.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        if (isCancelled?.call() ?? false) {
          throw const ApkDownloadException(ApkDownloadFailure.cancelled);
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.close();
      sink = null;
      if (asset.size != null && received != asset.size) {
        throw const ApkDownloadException(ApkDownloadFailure.damaged);
      }
      final expected = asset.sha256;
      if (expected != null) {
        final digest = await sha256.bind(partial.openRead()).first;
        if (digest.toString() != expected) {
          throw const ApkDownloadException(ApkDownloadFailure.damaged);
        }
      }
      if (await target.exists()) await target.delete();
      return await partial.rename(target.path);
    } on ApkDownloadException {
      await _discard(sink, partial);
      rethrow;
    } on Exception {
      await _discard(sink, partial);
      throw const ApkDownloadException(ApkDownloadFailure.network);
    }
  }

  /// Removes the files of earlier downloads from [directory], which is the
  /// app's own. A file that cannot be removed is only wasted space.
  Future<void> clear(Directory directory) async {
    try {
      if (!await directory.exists()) return;
      await for (final entry in directory.list()) {
        if (entry is File) await entry.delete();
      }
    } on FileSystemException {
      // Nothing more to do.
    }
  }

  Future<void> _discard(IOSink? sink, File partial) async {
    try {
      await sink?.close();
      if (await partial.exists()) await partial.delete();
    } on Exception {
      // Nothing more to do for a leftover partial file.
    }
  }

  void close() => _client.close();
}
