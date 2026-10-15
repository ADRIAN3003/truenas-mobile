import '../api/credentials.dart';
import '../api/server_address.dart';

enum AuthMethod { apiKey, password }

/// A saved TrueNAS server. Stored only in the platform's secure storage
/// (Keychain on iOS, Keystore-backed storage on Android), because it holds
/// the API key or password.
class ServerInstance {
  const ServerInstance({
    required this.id,
    required this.name,
    required this.url,
    required this.authMethod,
    required this.username,
    required this.secret,
    this.pinnedFingerprint,
    this.lastApiVersion,
  });

  factory ServerInstance.fromJson(Map<String, dynamic> json) => ServerInstance(
    id: json['id'] as String,
    name: json['name'] as String,
    url: json['url'] as String,
    authMethod: AuthMethod.values.byName(json['authMethod'] as String),
    username: json['username'] as String,
    secret: json['secret'] as String,
    pinnedFingerprint: json['pinnedFingerprint'] as String?,
    lastApiVersion: json['lastApiVersion'] as String?,
  );

  final String id;
  final String name;
  final String url;
  final AuthMethod authMethod;
  final String username;

  /// The API key or the password, depending on [authMethod].
  final String secret;

  /// SHA-256 fingerprint of a self-signed certificate the user chose to trust.
  final String? pinnedFingerprint;

  /// API version used on the last successful connection, e.g. `v25.10.5`.
  final String? lastApiVersion;

  ServerAddress get address => ServerAddress.tryParse(url)!;

  Credentials get credentials => switch (authMethod) {
    AuthMethod.apiKey => ApiKeyCredentials(username: username, apiKey: secret),
    AuthMethod.password => PasswordCredentials(
      username: username,
      password: secret,
    ),
  };

  ServerInstance copyWith({
    String? name,
    String? url,
    AuthMethod? authMethod,
    String? username,
    String? secret,
    String? Function()? pinnedFingerprint,
    String? lastApiVersion,
  }) => ServerInstance(
    id: id,
    name: name ?? this.name,
    url: url ?? this.url,
    authMethod: authMethod ?? this.authMethod,
    username: username ?? this.username,
    secret: secret ?? this.secret,
    pinnedFingerprint: pinnedFingerprint != null
        ? pinnedFingerprint()
        : this.pinnedFingerprint,
    lastApiVersion: lastApiVersion ?? this.lastApiVersion,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'authMethod': authMethod.name,
    'username': username,
    'secret': secret,
    'pinnedFingerprint': pinnedFingerprint,
    'lastApiVersion': lastApiVersion,
  };
}
