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

  /// Service that holds snapshot methods: `pool.snapshot` (25.10+) or
  /// `zfs.snapshot` (25.04).
  String snapshotService = 'pool.snapshot';

  /// Every method call received, with its params.
  final calls = <(String, List<dynamic>)>[];

  /// Datasets served by `pool.dataset.query`; create and delete change them.
  final datasets = <Map<String, dynamic>>[
    _dataset('tank', 1000, 3000),
    _dataset('tank/media', 800, 3000),
    _dataset('tank/vm', 100, 3000, volume: true),
  ];

  /// Snapshots served by the snapshot service's `query`.
  final snapshots = <Map<String, dynamic>>[
    _snapshot('tank/media@auto-1', 1760000000000),
    _snapshot('tank/media@auto-2', 1760100000000),
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
        final method = message['method'] as String;
        calls.add((method, params));
        if (method.startsWith('$snapshotService.')) {
          result = _snapshotCall(method.split('.').last, params);
        }
        switch (method) {
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
          case 'core.get_methods':
            final service = params.first as String;
            result = service == snapshotService
                ? {
                    for (final m in ['query', 'create', 'delete', 'rollback'])
                      '$service.$m': <String, dynamic>{},
                  }
                : <String, dynamic>{};
          case 'pool.query':
            result = [samplePool];
          case 'pool.scrub.scrub':
            result = 12;
          case 'pool.dataset.query':
            result = datasets;
          case 'pool.dataset.create':
            final data = params.first as Map<String, dynamic>;
            datasets.add(
              _dataset(
                data['name'] as String,
                0,
                3000,
                volume: data['type'] == 'VOLUME',
              ),
            );
            result = datasets.last;
          case 'pool.dataset.delete':
            final id = params.first as String;
            datasets.removeWhere(
              (d) => d['id'] == id || (d['id'] as String).startsWith('$id/'),
            );
            result = true;
          case 'disk.query':
            result = [
              {
                'name': 'sda',
                'size': 4000000000000,
                'type': 'HDD',
                'serial': 'S1',
                'model': 'WD Red',
                'pool': 'tank',
                'rotationrate': 5400,
              },
              {
                'name': 'nvme0n1',
                'size': 500000000000,
                'type': 'SSD',
                'serial': 'S2',
                'model': 'Samsung 980',
                'pool': null,
              },
            ];
          case 'disk.temperatures':
            result = {'sda': 34, 'nvme0n1': null};
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

  Object? _snapshotCall(String method, List<dynamic> params) {
    switch (method) {
      case 'query':
        return snapshots;
      case 'create':
        final data = params.first as Map<String, dynamic>;
        snapshots.add(
          _snapshot('${data['dataset']}@${data['name']}', 1760200000000),
        );
        return snapshots.last;
      case 'delete':
        snapshots.removeWhere((s) => s['id'] == params.first);
        return true;
    }
    return null;
  }

  Map<String, Object?> _success() => {
    'response_type': 'SUCCESS',
    'authenticator': 'LEVEL_1',
    'user_info': {'pw_name': username},
  };
}

Map<String, dynamic> _dataset(
  String id,
  int used,
  int available, {
  bool volume = false,
}) => {
  'id': id,
  'name': id,
  'pool': id.split('/').first,
  'type': volume ? 'VOLUME' : 'FILESYSTEM',
  'encrypted': false,
  'locked': false,
  'mountpoint': volume ? null : '/mnt/$id',
  'used': {'parsed': used, 'value': '$used'},
  'available': {'parsed': available, 'value': '$available'},
  'compression': {'parsed': 'lz4', 'value': 'LZ4'},
  'compressratio': {'parsed': '1.50', 'value': '1.50x'},
  if (volume) 'volsize': {'parsed': 1073741824, 'value': '1G'},
};

Map<String, dynamic> _snapshot(String id, int created) => {
  'id': id,
  'name': id,
  'dataset': id.split('@').first,
  'snapshot_name': id.split('@').last,
  'properties': {
    'used': {'parsed': 1024},
    'referenced': {'parsed': 4096},
    'creation': {
      'parsed': {r'$date': created},
    },
  },
};

/// A `pool.query` entry with topology and a finished scrub.
const samplePool = {
  'id': 1,
  'name': 'tank',
  'status': 'ONLINE',
  'healthy': true,
  'size': 4000,
  'allocated': 1000,
  'free': 3000,
  'status_detail': null,
  'scan': {
    'function': 'SCRUB',
    'state': 'FINISHED',
    'percentage': 100.0,
    'errors': 0,
    'pause': null,
    'end_time': {r'$date': 1760000000000},
  },
  'topology': {
    'data': [
      {
        'name': 'mirror-0',
        'type': 'MIRROR',
        'status': 'ONLINE',
        'stats': {'read_errors': 0, 'write_errors': 0, 'checksum_errors': 0},
        'children': [
          {
            'name': 'sda1',
            'type': 'DISK',
            'status': 'ONLINE',
            'disk': 'sda',
            'stats': {
              'read_errors': 0,
              'write_errors': 0,
              'checksum_errors': 0,
            },
            'children': [],
          },
          {
            'name': 'sdb1',
            'type': 'DISK',
            'status': 'DEGRADED',
            'disk': 'sdb',
            'stats': {
              'read_errors': 2,
              'write_errors': 0,
              'checksum_errors': 1,
            },
            'children': [],
          },
        ],
      },
    ],
    'log': [],
    'cache': [],
    'spare': [],
    'special': [],
    'dedup': [],
  },
};

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
