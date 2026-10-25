/// Removes what must never end up in the error log: passwords, tokens, API
/// keys and the like. The log can be copied and shared, so it is scrubbed when
/// an entry is written, not when it is shown.
///
/// Server addresses are kept: they are what a bug report needs, and the
/// log screen says so.
String redactSecrets(String text) {
  var out = text;
  // `Authorization: Basic abc`, `Bearer abc`.
  out = out.replaceAllMapped(
    RegExp(
      r'\b(authorization\s*[:=]\s*)?(bearer|basic)\s+[A-Za-z0-9._~+/=-]{6,}',
      caseSensitive: false,
    ),
    (m) => '${m[1] ?? ''}${m[2]} [redacted]',
  );
  // `user:secret@host` in a URL.
  out = out.replaceAllMapped(
    RegExp(r'([a-z][a-z0-9+.-]*://)[^\s/@]+@', caseSensitive: false),
    (m) => '${m[1]}[redacted]@',
  );
  // `password: x`, `"api_key": "x"`, `?token=x`, `secret=x`.
  out = out.replaceAllMapped(_secretPair, (m) => '${m[1]}[redacted]');
  // A long run of letters and digits is a key or token, whatever it is
  // called (TrueNAS API keys are `1-` and 64 characters).
  out = out.replaceAllMapped(
    RegExp(r'[A-Za-z0-9_-]{32,}'),
    (m) => _looksLikeSecret(m[0]!) ? '[redacted]' : m[0]!,
  );
  return out;
}

final _secretPair = RegExp(
  r'''((?:[\w-]*(?:password|passwd|passphrase|secret|token|api[_-]?key|private[_-]?key|access[_-]?key|credential|otp)[\w-]*)["']?\s*[:=]\s*["']?)(?:"[^"]*"|'[^']*'|[^\s"',;&}\])]+)''',
  caseSensitive: false,
);

/// Letters and digits both, so a long identifier made of words (a dataset or
/// method name) stays readable.
bool _looksLikeSecret(String run) =>
    run.contains(RegExp(r'[0-9]')) && run.contains(RegExp(r'[A-Za-z]'));
