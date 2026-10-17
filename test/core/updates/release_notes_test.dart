import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/updates/release_notes.dart';

void main() {
  const repo = 'https://github.com/ADRIAN3003/truenas-mobile';

  test('a pull request URL becomes #id and stays a link', () {
    expect(
      shortenGitHubLinks('* Add alerts by @adrian in $repo/pull/33'),
      '* Add alerts by @adrian in [#33]($repo/pull/33)',
    );
  });

  test('issues, angle autolinks and links whose text is the URL', () {
    expect(shortenGitHubLinks('$repo/issues/5.'), '[#5]($repo/issues/5).');
    expect(shortenGitHubLinks('<$repo/pull/7>'), '[#7]($repo/pull/7)');
    expect(
      shortenGitHubLinks('[$repo/pull/8]($repo/pull/8)'),
      '[#8]($repo/pull/8)',
    );
  });

  test('another repository keeps its name', () {
    expect(
      shortenGitHubLinks('https://github.com/truenas/middleware/pull/12'),
      '[truenas/middleware#12](https://github.com/truenas/middleware/pull/12)',
    );
  });

  test('a compare URL shows the two tags', () {
    expect(
      shortenGitHubLinks('**Full Changelog**: $repo/compare/v0.1.3...v0.1.4'),
      '**Full Changelog**: [v0.1.3...v0.1.4]($repo/compare/v0.1.3...v0.1.4)',
    );
  });

  test('links with their own text, code and other URLs are left alone', () {
    for (final text in [
      '[the fix]($repo/pull/9)',
      '`$repo/pull/9`',
      '```\n$repo/pull/9\n```',
      '[ref]: $repo/pull/9',
      '$repo/pull/9/files',
      '$repo/pull/9#issuecomment-1',
      '$repo/releases/tag/v0.1.3',
      'https://example.com/pull/9',
    ]) {
      expect(shortenGitHubLinks(text), text);
    }
  });
}
