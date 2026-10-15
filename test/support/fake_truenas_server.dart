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

  /// Alerts served by `alert.list`; `alert.dismiss` and `alert.restore`
  /// change them.
  final alerts = <Map<String, dynamic>>[
    {
      'uuid': 'a1',
      'level': 'CRITICAL',
      'klass': 'PoolStatus',
      'formatted': 'Pool tank state is <b>DEGRADED</b>',
      'dismissed': false,
      'datetime': {r'$date': 1760000000000},
    },
    {
      'uuid': 'a2',
      'level': 'INFO',
      'klass': 'Update',
      'formatted': 'An update is available',
      'dismissed': true,
      'datetime': {r'$date': 1760000000000},
    },
  ];

  /// Events passed to `core.subscribe`.
  final subscriptions = <String>[];

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
      void notify(String collection, String msg, Object? fields) => socket.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'collection_update',
          'params': {
            'msg': msg,
            'collection': collection,
            'id': 1,
            'fields': fields,
          },
        }),
      );
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
          case 'core.subscribe':
            subscriptions.add(params.first as String);
            result = 'sub-${subscriptions.length}';
          case 'core.unsubscribe':
            result = null;
          case 'pool.query':
            result = [
              {
                'name': 'tank',
                'status': 'ONLINE',
                'healthy': true,
                'size': 4000,
                'allocated': 1000,
              },
            ];
          case 'alert.list':
            result = alerts;
          case 'alert.dismiss' || 'alert.restore':
            final alert = alerts.firstWhere((a) => a['uuid'] == params.first);
            alert['dismissed'] = message['method'] == 'alert.dismiss';
          case 'core.get_jobs':
            result = [
              {
                'id': 7,
                'method': 'pool.scrub.run',
                'state': 'RUNNING',
                'progress': {'percent': 40, 'description': 'Scrubbing'},
                'abortable': true,
                'time_started': {r'$date': 1760000000000},
              },
            ];
        }
        socket.add(
          jsonEncode({'jsonrpc': '2.0', 'id': message['id'], 'result': result}),
        );
        if (message['method'] == 'core.subscribe' &&
            params.first == 'reporting.realtime') {
          notify('reporting.realtime', 'added', sampleRealtimeStats);
        }
        if (message['method'] == 'alert.dismiss' ||
            message['method'] == 'alert.restore') {
          notify('alert.list', 'changed', {'uuid': params.first});
        }
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

/// A `reporting.realtime` sample as TrueNAS 25.04 to 27 send it.
const sampleRealtimeStats = {
  'cpu': {
    'cpu': {'usage': 23.5, 'temp': 41.0},
    'cpu0': {'usage': 20.0, 'temp': null},
  },
  'memory': {
    'arc_size': 8 * 1024 * 1024 * 1024,
    'arc_free_memory': 0,
    'arc_available_memory': 0,
    'physical_memory_total': 32 * 1024 * 1024 * 1024,
    'physical_memory_available': 20 * 1024 * 1024 * 1024,
  },
  'interfaces': {
    'eno1': {
      'link_state': 'LINK_STATE_UP',
      'speed': 1000,
      'received_bytes_rate': 125000,
      'sent_bytes_rate': 25000,
    },
    'eno2': {
      'link_state': 'LINK_STATE_DOWN',
      'speed': 0,
      'received_bytes_rate': 0,
      'sent_bytes_rate': 0,
    },
  },
  'disks': {},
  'zfs': {},
  'pools': {},
};
