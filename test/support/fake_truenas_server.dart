import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A tiny stand-in for the TrueNAS middleware: serves `/api/versions` and a
/// JSON-RPC WebSocket at `/api/<version>` answering a few methods.
class FakeTrueNasServer {
  FakeTrueNasServer._(this._server, this.versions);

  static Future<FakeTrueNasServer> start({
    List<String>? versions = const ['v24.10', 'v25.04.2', 'v25.10.5'],
    SecurityContext? tls,
  }) async {
    final server = tls == null
        ? await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
        : await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, tls);
    final fake = FakeTrueNasServer._(server, versions);
    server.listen(fake._handle);
    return fake;
  }

  final HttpServer _server;

  /// Served at `/api/versions`; null answers 404.
  final List<String>? versions;

  String username = 'truenas_admin';
  String password = 'secret';
  String apiKey = '1-abcdef';
  String? otp;

  /// Paths of WebSocket connections, e.g. `/api/v25.10.5`.
  final connectedPaths = <String>[];

  int get port => _server.port;

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    if (request.uri.path == '/api/versions') {
      if (versions == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.write(jsonEncode(versions));
      }
      await request.response.close();
      return;
    }
    if (request.uri.path.startsWith('/api/') &&
        WebSocketTransformer.isUpgradeRequest(request)) {
      connectedPaths.add(request.uri.path);
      final socket = await WebSocketTransformer.upgrade(request);
      var awaitingOtp = false;
      socket.listen((raw) {
        final message = jsonDecode(raw as String) as Map<String, dynamic>;
        final params = message['params'] as List<dynamic>;
        Object? result;
        switch (message['method']) {
          case 'auth.login_ex':
            final data = params.first as Map<String, dynamic>;
            final ok =
                data['username'] == username &&
                (data['password'] == password || data['api_key'] == apiKey);
            if (!ok) {
              result = {'response_type': 'AUTH_ERR'};
            } else if (otp != null) {
              awaitingOtp = true;
              result = {'response_type': 'OTP_REQUIRED', 'username': username};
            } else {
              result = _success();
            }
          case 'auth.login_ex_continue':
            final data = params.first as Map<String, dynamic>;
            result = awaitingOtp && data['otp_token'] == otp
                ? _success()
                : {'response_type': 'AUTH_ERR'};
          case 'system.info':
            result = {'hostname': 'nas', 'version': '25.10.7'};
        }
        socket.add(
          jsonEncode({'jsonrpc': '2.0', 'id': message['id'], 'result': result}),
        );
      });
      return;
    }
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  Map<String, Object?> _success() => {
    'response_type': 'SUCCESS',
    'authenticator': 'LEVEL_1',
    'user_info': {'pw_name': username},
  };
}

/// A security context for the fixture certificate in `test/fixtures`.
SecurityContext testTlsContext() => SecurityContext()
  ..useCertificateChain('test/fixtures/test_cert.pem')
  ..usePrivateKey('test/fixtures/test_key.pem');

/// SHA-256 fingerprint of `test/fixtures/test_cert.pem`.
const testCertFingerprint =
    'CD:BC:91:D1:63:87:24:89:47:17:6C:6E:32:A3:1B:7E:'
    '7C:DF:18:44:9D:35:4C:BC:49:91:6A:06:1E:DA:6C:F6';
