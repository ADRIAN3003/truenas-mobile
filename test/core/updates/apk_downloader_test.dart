import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:truenas_mobile/core/updates/apk_downloader.dart';
import 'package:truenas_mobile/core/updates/release.dart';

void main() {
  late Directory dir;
  final chunks = [
    List.filled(1000, 1),
    List.filled(1000, 2),
    List.filled(500, 3),
  ];
  final bytes = [for (final c in chunks) ...c];
  final digest = sha256.convert(bytes).toString();

  setUp(() => dir = Directory.systemTemp.createTempSync('apk_downloader'));
  tearDown(() => dir.deleteSync(recursive: true));

  ApkDownloader downloader({int status = 200, Object? error}) => ApkDownloader(
    client: MockClient.streaming((request, _) async {
      if (error != null) throw error;
      return http.StreamedResponse(
        Stream.fromIterable(chunks),
        status,
        contentLength: bytes.length,
      );
    }),
  );

  ReleaseAsset asset({int? size, String? checksum}) => ReleaseAsset(
    name: 'app.apk',
    url: 'https://example.com/app.apk',
    size: size ?? bytes.length,
    sha256: checksum,
  );

  List<String> files() =>
      [for (final e in dir.listSync()) e.uri.pathSegments.last]..sort();

  test('saves the file and reports progress', () async {
    final progress = <(int, int?)>[];
    final file = await downloader().download(
      asset(checksum: digest),
      dir,
      onProgress: (received, total) => progress.add((received, total)),
    );
    expect(file.path, '${dir.path}/app.apk');
    expect(file.readAsBytesSync(), bytes);
    expect(progress, [(1000, 2500), (2000, 2500), (2500, 2500)]);
    expect(files(), ['app.apk'], reason: 'no partial file is left behind');
  });

  test('creates the folder and replaces an older download', () async {
    final nested = Directory('${dir.path}/updates');
    File('${dir.path}/updates/app.apk')
      ..createSync(recursive: true)
      ..writeAsStringSync('old');
    final file = await downloader().download(asset(), nested);
    expect(file.readAsBytesSync(), bytes);
  });

  test('a file that does not match its checksum is thrown away', () async {
    await expectLater(
      downloader().download(asset(checksum: 'a' * 64), dir),
      throwsA(
        isA<ApkDownloadException>().having(
          (e) => e.failure,
          'failure',
          ApkDownloadFailure.damaged,
        ),
      ),
    );
    expect(files(), isEmpty);
  });

  test('a file of the wrong size is thrown away', () async {
    await expectLater(
      downloader().download(asset(size: 123), dir),
      throwsA(
        isA<ApkDownloadException>().having(
          (e) => e.failure,
          'failure',
          ApkDownloadFailure.damaged,
        ),
      ),
    );
    expect(files(), isEmpty);
  });

  test('an HTTP error or a dropped connection is a network failure', () async {
    for (final d in [
      downloader(status: 404),
      downloader(error: const SocketException('gone')),
    ]) {
      await expectLater(
        d.download(asset(), dir),
        throwsA(
          isA<ApkDownloadException>().having(
            (e) => e.failure,
            'failure',
            ApkDownloadFailure.network,
          ),
        ),
      );
    }
    expect(files(), isEmpty);
  });

  test('cancelling stops the download and removes the partial file', () async {
    var asked = 0;
    await expectLater(
      downloader().download(
        asset(),
        dir,
        // Cancel while the second chunk is on its way.
        isCancelled: () => ++asked > 1,
      ),
      throwsA(
        isA<ApkDownloadException>().having(
          (e) => e.failure,
          'failure',
          ApkDownloadFailure.cancelled,
        ),
      ),
    );
    expect(files(), isEmpty);
  });
}
