import 'update_checker.dart';

/// Shortens the GitHub links in release notes the way GitHub does when it
/// renders them: a pull request or issue URL becomes `#123` (`owner/repo#123`
/// when it belongs to another repository) and a compare URL becomes
/// `v1...v2`. The result is still a Markdown link to the same address.
///
/// Links that already have their own text (`[the fix](https://...)`), code
/// spans and code blocks are left alone.
String shortenGitHubLinks(
  String markdown, {
  String repository = defaultUpdateRepository,
}) {
  return markdown.replaceAllMapped(_candidate, (Match match) {
    final m = match as RegExpMatch;
    // Code and reference definitions: untouched.
    if (m.namedGroup('keep') != null) return m[0]!;

    final linkText = m.namedGroup('text');
    final url = m.namedGroup('dest') ?? m.namedGroup('angle') ?? m[0]!;
    // `[text](url)` only changes when its text is just the URL.
    if (linkText != null && linkText.trim() != url) return m[0]!;

    final label = _label(url, repository);
    return label == null ? m[0]! : '[$label]($url)';
  });
}

const _ref = r'[\w.\-%]*[\w\-%]';
const _gitHubUrl =
    r'https://github\.com/(?:[\w.\-]+)/(?:[\w.\-]+)/'
    '(?:(?:pull|issues)/\\d+|compare/$_ref\\.\\.\\.$_ref)';

final _candidate = RegExp(
  '(?<keep>```[\\s\\S]*?```|`[^`\\n]*`|^[ ]{0,3}\\[[^\\]\\n]+\\]:[^\\n]*)'
  '|\\[(?<text>[^\\[\\]\\n]*)\\]\\((?<dest>[^)\\s]*)\\)'
  '|<(?<angle>$_gitHubUrl)>'
  '|$_gitHubUrl(?![\\w/#?\\-])',
  multiLine: true,
);

final _parts = RegExp(
  r'^https://github\.com/([\w.\-]+)/([\w.\-]+)/'
  '(?:(?:pull|issues)/(\\d+)|compare/($_ref\\.\\.\\.$_ref))\$',
);

String? _label(String url, String repository) {
  final m = _parts.firstMatch(url);
  if (m == null) return null;
  final compare = m[4];
  if (compare != null) return compare;
  final same = '${m[1]}/${m[2]}'.toLowerCase() == repository.toLowerCase();
  return '${same ? '' : '${m[1]}/${m[2]}'}#${m[3]}';
}
