import 'api_exception.dart';
import 'credentials.dart';
import 'json_rpc_client.dart';

/// Result of an `auth.login_ex` or `auth.login_ex_continue` call.
sealed class LoginOutcome {
  const LoginOutcome();
}

class LoginSucceeded extends LoginOutcome {
  const LoginSucceeded(this.userInfo);

  /// `auth.me` data for the signed-in user, when the server includes it.
  final Map<String, dynamic>? userInfo;
}

/// The account has two-factor authentication; call [Authenticator.submitOtp].
class LoginNeedsOtp extends LoginOutcome {
  const LoginNeedsOtp();
}

/// Rejected credentials, expired or revoked key, or access denied.
class LoginFailed extends LoginOutcome {
  const LoginFailed(this.reason);

  /// The server's `response_type`: `AUTH_ERR`, `EXPIRED`, `DENIED`, ...
  final String reason;
}

/// Signs in on an open JSON-RPC connection.
class Authenticator {
  const Authenticator(this._client);

  final JsonRpcClient _client;

  Future<LoginOutcome> login(Credentials credentials) =>
      _call('auth.login_ex', credentials.toLoginData());

  Future<LoginOutcome> submitOtp(String code) => _call(
    'auth.login_ex_continue',
    {'mechanism': 'OTP_TOKEN', 'otp_token': code.trim()},
  );

  Future<LoginOutcome> _call(String method, Map<String, Object?> data) async {
    final result = await _client.call(method, [data]);
    if (result is! Map<String, dynamic>) {
      throw ApiException('Unexpected $method response');
    }
    final type = result['response_type'];
    switch (type) {
      case 'SUCCESS':
        final info = result['user_info'];
        return LoginSucceeded(info is Map<String, dynamic> ? info : null);
      case 'OTP_REQUIRED':
        return const LoginNeedsOtp();
      default:
        return LoginFailed(type?.toString() ?? 'UNKNOWN');
    }
  }
}
