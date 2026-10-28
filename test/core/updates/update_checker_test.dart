import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:truenas_mobile/core/updates/release.dart';
import 'package:truenas_mobile/core/updates/update_checker.dart';

Map<String, dynamic> release(
  String tag, {
  String? body,
  bool draft = false,
  bool prerelease = false,
  List<Map<String, dynamic>> assets = const [],
}) => {
  'tag_name': tag,
  'name': tag,
  'body': body,
  'draft': draft,
  'prerelease': prerelease,
  'html_url': 'https://github.com/ADRIAN3003/truenas-mobile/releases/$tag',
  'published_at': '2026-10-16T10:00:00Z',
  'assets': assets,
};

Map<String, dynamic> asset(String name, {int size = 10, String? digest}) => {
  'name': name,
  'size': size,
  'browser_download_url': 'https://github.com/download/$name',
  'digest': ?digest,
};

UpdateChecker checker(
  Future<http.Response> Function(http.Request request) handler,
) => UpdateChecker(client: MockClient(handler));

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('lists published releases, newest first', () async {
    final releases = await checker(
      (_) async => json([
        release('v0.1.2'),
        release('v0.1.10', body: '  Notes  '),
        release('v0.2.0-rc1', prerelease: true),
        release('v0.9.0', draft: true),
        release('nightly'),
        release('v0.1.3'),
      ]),
    ).releases();
    expect(
      [for (final r in releases) r.version.toString()],
      ['0.1.10', '0.1.3', '0.1.2'],
    );
    expect(releases.first.notes, 'Notes', reason: 'trimmed');
    expect(releases.first.publishedAt, DateTime.utc(2026, 10, 16, 10));
    expect(
      releases.first.url,
      'https://github.com/ADRIAN3003/truenas-mobile/releases/v0.1.10',
    );
  });

  test('asks GitHub for the repository releases', () async {
    late http.Request seen;
    await checker((request) async {
      seen = request;
      return json([]);
    }).releases();
    expect(seen.url.host, 'api.github.com');
    expect(seen.url.path, '/repos/ADRIAN3003/truenas-mobile/releases');
    expect(seen.headers['Accept'], 'application/vnd.github+json');
    expect(seen.headers['User-Agent'], isNotEmpty);
  });

  group('latest', () {
    test('asks for the release GitHub marks as latest', () async {
      late http.Request seen;
      final latest = await checker((request) async {
        seen = request;
        return json(release('v0.1.3', body: ' Notes '));
      }).latest();
      expect(seen.url.path, '/repos/ADRIAN3003/truenas-mobile/releases/latest');
      expect(seen.headers['Accept'], 'application/vnd.github+json');
      expect(latest?.version.toString(), '0.1.3');
      expect(latest?.notes, 'Notes');
    });

    test('no release yet, or a tag that is not a version, is null', () async {
      expect(await checker((_) async => json({}, 404)).latest(), isNull);
      expect(
        await checker((_) async => json(release('nightly'))).latest(),
        isNull,
      );
      expect(
        await checker((_) async => json(release('v1.0.0', draft: true)))
            .latest(),
        isNull,
      );
    });

    test('failures are told apart like the list', () async {
      await expectLater(
        checker((_) async => json({}, 403)).latest(),
        throwsA(
          isA<UpdateCheckException>().having(
            (e) => e.failure,
            'failure',
            UpdateCheckFailure.rateLimited,
          ),
        ),
      );
      await expectLater(
        checker((_) async => json({}, 500)).latest(),
        throwsA(
          isA<UpdateCheckException>().having(
            (e) => e.failure,
            'failure',
            UpdateCheckFailure.server,
          ),
        ),
      );
      await expectLater(
        checker((_) async => json([1])).latest(),
        throwsA(
          isA<UpdateCheckException>().having(
            (e) => e.failure,
            'failure',
            UpdateCheckFailure.network,
          ),
        ),
      );
    });
  });

  test('no releases is an empty list', () async {
    expect(await checker((_) async => json([])).releases(), isEmpty);
  });

  test('a rate limit is told apart from other errors', () async {
    for (final status in [403, 429]) {
      await expectLater(
        checker((_) async => json({'message': 'rate limit'}, status))
            .releases(),
        throwsA(
          isA<UpdateCheckException>().having(
            (e) => e.failure,
            'failure',
            UpdateCheckFailure.rateLimited,
          ),
        ),
      );
    }
    await expectLater(
      checker((_) async => json({}, 500)).releases(),
      throwsA(
        isA<UpdateCheckException>().having(
          (e) => e.failure,
          'failure',
          UpdateCheckFailure.server,
        ),
      ),
    );
  });

  test(
    'no connection, a timeout and a bad reply are network failures',
    () async {
      final failures = <UpdateCheckFailure>[];
      final cases = <UpdateChecker>[
        checker((_) async => throw http.ClientException('offline')),
        UpdateChecker(
          client: MockClient((_) => Completer<http.Response>().future),
          timeout: const Duration(milliseconds: 20),
        ),
        checker((_) async => http.Response('<html>', 200)),
        checker((_) async => json({'not': 'a list'})),
      ];
      for (final c in cases) {
        try {
          await c.releases();
        } on UpdateCheckException catch (e) {
          failures.add(e.failure);
        }
      }
      expect(failures, everyElement(UpdateCheckFailure.network));
      expect(failures, hasLength(4));
    },
  );

  group('assets', () {
    final assets = [
      asset('truenas-mobile-v0.1.3-arm64-v8a-release.apk', size: 30),
      asset('truenas-mobile-v0.1.3-armeabi-v7a-release.apk'),
      asset('truenas-mobile-v0.1.3-x86_64-release.apk'),
      asset('truenas-mobile-v0.1.3-release.apk'),
      asset('truenas-mobile-v0.1.3-release.aab'),
      asset('truenas-mobile-v0.1.3-unsigned.ipa'),
    ];
    final info = ReleaseInfo.fromJson(release('v0.1.3', assets: assets))!;

    test('the best matching per-ABI APK wins', () {
      expect(
        info.apkFor(['arm64-v8a', 'armeabi-v7a'])?.name,
        'truenas-mobile-v0.1.3-arm64-v8a-release.apk',
      );
      expect(
        info.apkFor(['armeabi-v7a'])?.name,
        'truenas-mobile-v0.1.3-armeabi-v7a-release.apk',
      );
      expect(
        info.apkFor(['x86_64', 'x86'])?.name,
        'truenas-mobile-v0.1.3-x86_64-release.apk',
      );
    });

    test('an ABI without a build of its own gets the universal APK', () {
      expect(
        info.apkFor(['x86'])?.name,
        'truenas-mobile-v0.1.3-release.apk',
        reason: 'x86 must not match the x86_64 file',
      );
      expect(info.apkFor([])?.name, 'truenas-mobile-v0.1.3-release.apk');
    });

    test('bundles and iOS builds are not APKs', () {
      final onlyOthers = ReleaseInfo.fromJson(
        release(
          'v0.1.3',
          assets: [
            asset('truenas-mobile-v0.1.3-release.aab'),
            asset('truenas-mobile-v0.1.3-unsigned.ipa'),
          ],
        ),
      )!;
      expect(onlyOthers.apkFor(['arm64-v8a']), isNull);
    });

    test('reads the size and the SHA-256 digest', () {
      final withDigest = ReleaseAsset.fromJson(
        asset('a.apk', size: 12, digest: 'sha256:ABCDEF'),
      );
      expect(withDigest.size, 12);
      expect(withDigest.sha256, 'abcdef');
      expect(ReleaseAsset.fromJson(asset('a.apk')).sha256, isNull);
      expect(
        ReleaseAsset.fromJson(asset('a.apk', digest: 'md5:abc')).sha256,
        isNull,
      );
    });
  });
}
