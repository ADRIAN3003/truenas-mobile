/// How the app signs in to a TrueNAS server.
sealed class Credentials {
  const Credentials(this.username);

  final String username;

  /// The `login_data` for `auth.login_ex`.
  Map<String, Object?> toLoginData();
}

/// An API key created in TrueNAS (Credentials > Users > API keys).
/// Since 25.04 every key belongs to a user, so the username is required.
class ApiKeyCredentials extends Credentials {
  const ApiKeyCredentials({required String username, required this.apiKey})
    : super(username);

  final String apiKey;

  @override
  Map<String, Object?> toLoginData() => {
    'mechanism': 'API_KEY_PLAIN',
    'username': username,
    'api_key': apiKey,
  };
}

class PasswordCredentials extends Credentials {
  const PasswordCredentials({required String username, required this.password})
    : super(username);

  final String password;

  @override
  Map<String, Object?> toLoginData() => {
    'mechanism': 'PASSWORD_PLAIN',
    'username': username,
    'password': password,
  };
}
