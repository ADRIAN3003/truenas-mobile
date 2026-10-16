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

/// Lists the app's published releases on GitHub. Only the public releases API
/// is used, without a sign-in; nothing about the user or their servers is
/// sent.
class UpdateChecker {
  UpdateChecker({
    http.Client? client,
    this.repository = 'ADRIAN3003/truenas-mobile',
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  /// `owner/name` of the GitHub repository.
  final String repository;
  final Duration timeout;
  final http.Client _client;

  /// The published releases (no drafts, no pre-releases, no tags that are not
  /// versions), newest first.
  Future<List<ReleaseInfo>> releases() async {
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.https('api.github.com', '/repos/$repository/releases', {
              'per_page': '30',
            }),
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
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw const UpdateCheckException(UpdateCheckFailure.rateLimited);
    }
    if (response.statusCode != 200) {
      throw const UpdateCheckException(UpdateCheckFailure.server);
    }
    final List<dynamic> list;
    try {
      list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    } on Exception {
      throw const UpdateCheckException(UpdateCheckFailure.network);
    } on TypeError {
      throw const UpdateCheckException(UpdateCheckFailure.network);
    }
    final releases = <ReleaseInfo>[
      for (final item in list)
        if (item is Map<String, dynamic> &&
            item['draft'] != true &&
            item['prerelease'] != true)
          ?ReleaseInfo.fromJson(item),
    ];
    releases.sort((a, b) => b.version.compareTo(a.version));
    return releases;
  }

  void close() => _client.close();
}
