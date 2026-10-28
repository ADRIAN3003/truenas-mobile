import 'dart:convert';

import 'package:http/http.dart' as http;

import 'release.dart';

/// Why looking for releases failed.
enum UpdateCheckFailure {
  /// No connection, a timeout or a reply that is not what GitHub sends.
  network,

  /// GitHub limits requests that carry no sign-in, per network address.
  rateLimited,

  /// GitHub answered with an error.
  server,
}

class UpdateCheckException implements Exception {
  const UpdateCheckException(this.failure);

  final UpdateCheckFailure failure;

  @override
  String toString() => 'UpdateCheckException($failure)';
}

/// `owner/name` of the repository the app's releases are published in.
const defaultUpdateRepository = 'ADRIAN3003/truenas-mobile';

/// Looks up the app's published releases on GitHub. Only the public releases API
/// is used, without a sign-in; nothing about the user or their servers is
/// sent.
class UpdateChecker {
  UpdateChecker({
    http.Client? client,
    this.repository = defaultUpdateRepository,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  /// `owner/name` of the GitHub repository.
  final String repository;
  final Duration timeout;
  final http.Client _client;

  /// The release GitHub marks as the latest one (never a draft or a
  /// pre-release), or null when it is not a version number or the repository
  /// has no release yet. One small request, which is what the check when the
  /// app opens needs.
  Future<ReleaseInfo?> latest() async {
    final body = await _get(
      '/repos/$repository/releases/latest',
      emptyOn404: true,
    );
    if (body == null) return null;
    if (body is! Map<String, dynamic>) {
      throw const UpdateCheckException(UpdateCheckFailure.network);
    }
    if (body['draft'] == true || body['prerelease'] == true) return null;
    return ReleaseInfo.fromJson(body);
  }

  /// The published releases (no drafts, no pre-releases, no tags that are not
  /// versions), newest first.
  Future<List<ReleaseInfo>> releases() async {
    final body = await _get(
      '/repos/$repository/releases',
      query: {'per_page': '30'},
    );
    if (body is! List<dynamic>) {
      throw const UpdateCheckException(UpdateCheckFailure.network);
    }
    final releases = <ReleaseInfo>[
      for (final item in body)
        if (item is Map<String, dynamic> &&
            item['draft'] != true &&
            item['prerelease'] != true)
          ?ReleaseInfo.fromJson(item),
    ];
    releases.sort((a, b) => b.version.compareTo(a.version));
    return releases;
  }

  /// The decoded JSON at [path]. With [emptyOn404] a 404 gives null instead of
  /// a failure: `releases/latest` answers it when there is no release yet.
  Future<Object?> _get(
    String path, {
    Map<String, String>? query,
    bool emptyOn404 = false,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.https('api.github.com', path, query),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'User-Agent': 'truenas-mobile',
            },
          )
          .timeout(timeout);
    } on Exception {
      throw const UpdateCheckException(UpdateCheckFailure.network);
    }
    if (emptyOn404 && response.statusCode == 404) return null;
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw const UpdateCheckException(UpdateCheckFailure.rateLimited);
    }
    if (response.statusCode != 200) {
      throw const UpdateCheckException(UpdateCheckFailure.server);
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on Exception {
      throw const UpdateCheckException(UpdateCheckFailure.network);
    }
  }

  void close() => _client.close();
}
