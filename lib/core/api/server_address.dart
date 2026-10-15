/// A normalized TrueNAS server address, as typed by the user.
///
/// Accepts `nas.local`, `192.168.1.10:8443`, `https://nas.example.com/` and
/// `http://nas.local`. Without a scheme, HTTPS is assumed.
class ServerAddress {
  const ServerAddress._(this.uri);

  final Uri uri;

  static ServerAddress? tryParse(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;
    if (!text.contains('://')) text = 'https://$text';
    final Uri parsed;
    try {
      parsed = Uri.parse(text);
    } on FormatException {
      return null;
    }
    if (parsed.scheme != 'https' && parsed.scheme != 'http') return null;
    if (parsed.host.isEmpty) return null;
    return ServerAddress._(
      Uri(
        scheme: parsed.scheme,
        host: parsed.host,
        port: parsed.hasPort ? parsed.port : null,
      ),
    );
  }

  /// Whether traffic is encrypted. TrueNAS revokes API keys that are used
  /// over plain HTTP, so the app only allows API keys on HTTPS.
  bool get isSecure => uri.scheme == 'https';

  /// `https://host[:port]/api/versions`
  Uri get versionsUri => uri.replace(path: '/api/versions');

  /// `wss://host[:port]/api/<version>`
  Uri webSocketUri(String apiVersion) =>
      uri.replace(scheme: isSecure ? 'wss' : 'ws', path: '/api/$apiVersion');

  /// A WebSocket on this server at [path], e.g. `wss://host/_shell/`.
  Uri socketUri(String path) =>
      uri.replace(scheme: isSecure ? 'wss' : 'ws', path: path);

  /// The address as stored and shown, e.g. `https://nas.local:8443`.
  @override
  String toString() => uri.toString();

  @override
  bool operator ==(Object other) => other is ServerAddress && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;
}
