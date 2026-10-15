import '../api/api_exception.dart';
import '../api/auth.dart';
import '../api/certificate_trust.dart';
import '../api/json_rpc_client.dart';
import '../api/truenas_connection.dart';
import '../instances/server_instance.dart';

/// A signed-in connection to one server.
class TrueNasSession {
  TrueNasSession(this.connection, this.userInfo);

  final TrueNasConnection connection;
  final Map<String, dynamic>? userInfo;

  String get apiVersion => connection.apiVersion;
  JsonRpcClient get client => connection.client;

  Future<Map<String, dynamic>> systemInfo() async =>
      (await client.call('system.info')) as Map<String, dynamic>;

  Future<void> close() => connection.close();
}

/// Thrown when the user cancels a certificate or 2FA prompt.
class ConnectCancelled implements Exception {
  const ConnectCancelled();
}

/// Thrown when the server rejects the saved credentials.
class LoginRejected implements Exception {
  const LoginRejected(this.reason);

  final String reason;
}

/// Asks the user whether to trust a certificate. Returns true to pin it.
typedef ConfirmCertificate = Future<bool> Function(
  UntrustedCertificate certificate,
);

/// Asks the user for a 2FA code. Returns null when cancelled.
typedef AskOtp = Future<String?> Function();

/// Connects and signs in to [instance], asking the user when a certificate
/// needs trusting or a 2FA code is required.
///
/// Returns the session and the instance as it should now be saved (with a
/// newly pinned fingerprint and the API version in use).
Future<(TrueNasSession, ServerInstance)> connectToInstance(
  ServerInstance instance, {
  required ConfirmCertificate confirmCertificate,
  required AskOtp askOtp,
}) async {
  var current = instance;
  TrueNasConnection connection;
  try {
    connection = await TrueNasConnection.open(
      current.address,
      pinnedFingerprint: current.pinnedFingerprint,
    );
  } on UntrustedCertificateException catch (e) {
    if (!await confirmCertificate(e.certificate)) {
      throw const ConnectCancelled();
    }
    current = current.copyWith(
      pinnedFingerprint: () => e.certificate.fingerprint,
    );
    connection = await TrueNasConnection.open(
      current.address,
      pinnedFingerprint: current.pinnedFingerprint,
    );
  }

  try {
    final auth = Authenticator(connection.client);
    var outcome = await auth.login(current.credentials);
    while (outcome is LoginNeedsOtp) {
      final code = await askOtp();
      if (code == null) throw const ConnectCancelled();
      outcome = await auth.submitOtp(code);
    }
    switch (outcome) {
      case LoginSucceeded(:final userInfo):
        current = current.copyWith(lastApiVersion: connection.apiVersion);
        return (TrueNasSession(connection, userInfo), current);
      case LoginFailed(:final reason):
        throw LoginRejected(reason);
      case LoginNeedsOtp():
        throw const ApiException('Unexpected 2FA state');
    }
  } catch (_) {
    await connection.close();
    rethrow;
  }
}
