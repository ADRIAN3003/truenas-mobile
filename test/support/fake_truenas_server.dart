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

  /// Served by `alert.list_categories`: the kinds of alert, by category.
  final alertCategories = <Map<String, dynamic>>[
    {
      'id': 'STORAGE',
      'title': 'Storage',
      'classes': [
        {'id': 'PoolStatus', 'title': 'Pool Status', 'level': 'CRITICAL'},
        {'id': 'ScrubPaused', 'title': 'Scrub Paused', 'level': 'WARNING'},
      ],
    },
  ];

  /// Service that holds snapshot methods: `pool.snapshot` (25.10+) or
  /// `zfs.snapshot` (25.04).
  String snapshotService = 'pool.snapshot';

  /// Whether the snapshot service offers `clone`.
  bool snapshotClone = true;

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

  /// Pools served by `pool.query`.
  List<Map<String, dynamic>> pools = [samplePool];

  /// Behave like 25.04: no `service.control`, no NVMe-oF, SMB `ro` field.
  bool legacy = false;

  /// Services served by `service.query`; control calls change their state.
  final services = <Map<String, dynamic>>[
    {
      'id': 1,
      'service': 'cifs',
      'enable': true,
      'state': 'RUNNING',
      'pids': [],
    },
    {
      'id': 2,
      'service': 'nfs',
      'enable': false,
      'state': 'STOPPED',
      'pids': [],
    },
    {'id': 3, 'service': 'ssh', 'enable': true, 'state': 'RUNNING', 'pids': []},
  ];

  /// SMB shares served by `sharing.smb.query`.
  late final smbShares = <Map<String, dynamic>>[
    {
      'id': 1,
      'name': 'media',
      'path': '/mnt/tank/media',
      'enabled': true,
      'comment': 'Movies',
      legacy ? 'ro' : 'readonly': false,
      'browsable': true,
      'locked': false,
      'purpose': 'DEFAULT_SHARE',
    },
  ];

  /// NFS exports served by `sharing.nfs.query`.
  final nfsShares = <Map<String, dynamic>>[
    {
      'id': 1,
      'path': '/mnt/tank/media',
      'enabled': true,
      'comment': '',
      'ro': true,
      'networks': ['192.168.1.0/24'],
      'hosts': [],
      'locked': false,
    },
  ];

  /// Apps served by `app.query`; actions change their state.
  final apps = <Map<String, dynamic>>[
    {
      'name': 'jellyfin',
      'id': 'jellyfin',
      'state': 'RUNNING',
      'human_version': '10.10.7_1.2.3',
      'version': '1.2.3',
      'latest_version': '1.2.4',
      'upgrade_available': true,
      'image_updates_available': false,
      'custom_app': false,
      'metadata': {'title': 'Jellyfin'},
      'active_workloads': {
        'containers': 1,
        'images': ['jellyfin/jellyfin:10.10.7'],
      },
      'portals': {'Web UI': 'http://nas:30013/'},
      'notes': null,
    },
  ];

  /// Apps whose `app.upgrade` fails.
  final failingUpgrades = <String>{};

  /// When true a `core.bulk` job over apps stays RUNNING, changing nothing,
  /// until [finishBulk] runs it.
  bool holdBulk = false;

  /// Calls to `core.bulk`: the method and the argument lists.
  final bulkCalls = <(String, List<dynamic>)>[];

  /// VMs served by `vm.query`.
  final vms = <Map<String, dynamic>>[
    {
      'id': 1,
      'name': 'win11',
      'description': 'Gaming',
      'vcpus': 1,
      'cores': 4,
      'threads': 2,
      'memory': 8192,
      'autostart': false,
      'status': {'state': 'STOPPED', 'pid': null, 'domain_state': 'SHUTOFF'},
    },
  ];

  /// Containers: `container.query` rows, or `virt.instance.query` rows
  /// when [legacy].
  late final containers = <Map<String, dynamic>>[
    if (legacy)
      {
        'id': 'debian',
        'name': 'debian',
        'type': 'CONTAINER',
        'status': 'RUNNING',
        'autostart': true,
        'image': {'os': 'Debian', 'release': 'bookworm'},
      }
    else
      {
        'id': 3,
        'name': 'debian',
        'description': 'Build box',
        'autostart': true,
        'status': {'state': 'RUNNING', 'pid': 42, 'domain_state': 'RUNNING'},
      },
  ];

  /// Users served by `user.query`; create, update and delete change them.
  final users = <Map<String, dynamic>>[
    {
      'id': 1,
      'uid': 0,
      'username': 'root',
      'full_name': 'root',
      'builtin': true,
      'locked': false,
      'smb': false,
      'local': true,
    },
    {
      'id': 70,
      'uid': 3000,
      'username': 'alice',
      'full_name': 'Alice Smith',
      'builtin': false,
      'locked': false,
      'smb': true,
      'local': true,
      'twofactor_auth_configured': true,
    },
  ];

  /// Groups served by `group.query`.
  final groups = <Map<String, dynamic>>[
    {
      'id': 40,
      'gid': 3000,
      'name': 'alice',
      'builtin': false,
      'users': [70],
      'local': true,
    },
  ];

  /// API keys served by `api_key.query`.
  final apiKeys = <Map<String, dynamic>>[
    {
      'id': 1,
      'name': 'home-assistant',
      'username': 'truenas_admin',
      'revoked': false,
      'created_at': {r'$date': 1760000000000},
      'expires_at': null,
    },
  ];

  /// Boot environments served by `boot.environment.query`.
  final bootEnvironments = <Map<String, dynamic>>[
    {
      'id': '25.10.6',
      'active': false,
      'activated': false,
      'keep': false,
      'can_activate': true,
      'used_bytes': 3000000000,
      'created': {r'$date': 1750000000000},
    },
    {
      'id': '25.10.7',
      'active': true,
      'activated': true,
      'keep': false,
      'can_activate': true,
      'used_bytes': 3200000000,
      'created': {r'$date': 1760000000000},
    },
  ];

  /// Version offered by the update check, or null when up to date.
  String? availableUpdate = '25.10.8';

  /// Token handed out by `auth.generate_token` and accepted by `/websocket/shell/`.
  String shellToken = 'shell-token';
  List<dynamic>? shellTokenParams;

  /// Refuse every shell, as for a user without web shell access.
  bool shellDenied = false;
  Map<String, dynamic>? shellOptions;

  /// Every shell the app asked for, oldest first.
  final shellAttempts = <Map<String, dynamic>>[];

  /// Shells missing from the container: asking for one prints the container
  /// runtime's error and ends the shell. A request without a `command` asks
  /// for `/bin/bash`, the server's default.
  final missingShells = <String>{};
  final shellInput = StringBuffer();
  final shellResizes = <List<dynamic>>[];

  /// What `core.get_methods` returns without a service filter.
  final methodDocs = <String, dynamic>{
    'system.info': {
      'description': 'Returns basic system information.',
      'job': false,
      'filterable': false,
      'roles': ['READONLY_ADMIN'],
      'accepts': [],
      'returns': [
        {'type': 'object', 'title': 'system_info'},
      ],
    },
    'pool.query': {
      'description': 'Query pools.\n\nLonger details.',
      'job': false,
      'filterable': true,
      'accepts': [
        {
          'type': 'array',
          '_name_': 'filters',
          '_required_': false,
          'default': [],
        },
        {
          'type': 'object',
          '_name_': 'options',
          '_required_': false,
          'default': {},
        },
      ],
    },
    'test.fail': {
      'description': 'Always fails validation.',
      'job': false,
      'accepts': [
        {'type': 'string', '_name_': 'name', '_required_': true},
      ],
    },
    'test.job': {
      'description': 'Runs a job.',
      'job': true,
      'accepts': [
        {
          '_name_': 'mode',
          '_required_': true,
          'anyOf': [
            {'const': 'FAST'},
            {'const': 'SLOW'},
          ],
        },
        {'type': 'boolean', '_name_': 'force', '_required_': false},
      ],
    },
    'user.update': {
      'description': 'Update a user.',
      'job': false,
      'accepts': [
        {'type': 'integer', '_name_': 'id', '_required_': true},
        {
          'type': 'object',
          '_name_': 'user_update',
          '_required_': true,
          'properties': {
            'full_name': {'type': 'string', '_required_': false},
            'locked': {'type': 'boolean', '_required_': true},
          },
        },
      ],
    },
  };

  /// Data protection tasks by service; remove a key to hide that kind.
  final protection = <String, List<Map<String, dynamic>>>{
    'pool.snapshottask': [
      {
        'id': 1,
        'dataset': 'tank/media',
        'recursive': true,
        'lifetime_value': 2,
        'lifetime_unit': 'WEEK',
        'enabled': true,
        'schedule': {
          'minute': '00',
          'hour': '*',
          'dom': '*',
          'month': '*',
          'dow': '*',
          'begin': '00:00',
          'end': '23:59',
        },
        'state': {
          'state': 'FINISHED',
          'datetime': {r'$date': 1760000000000},
        },
      },
    ],
    'replication': [
      {
        'id': 1,
        'name': 'offsite',
        'direction': 'PUSH',
        'source_datasets': ['tank/media'],
        'target_dataset': 'backup/media',
        'enabled': true,
        'state': {
          'state': 'ERROR',
          'datetime': {r'$date': 1760000000000},
          'error': 'No route to host',
        },
        'job': null,
      },
    ],
    'cloudsync': [
      {
        'id': 1,
        'description': 'Photos to B2',
        'direction': 'PUSH',
        'path': '/mnt/tank/photos',
        'credentials': {'id': 1, 'name': 'Backblaze'},
        'enabled': false,
        'job': {
          'id': 5,
          'state': 'RUNNING',
          'progress': {'percent': 42},
        },
      },
    ],
    'cloud_backup': [],
    'rsynctask': [
      {
        'id': 1,
        'desc': 'Mirror to backup box',
        'path': '/mnt/tank/media',
        'user': 'root',
        'mode': 'MODULE',
        'remotehost': 'backup.lan',
        'remotemodule': 'media',
        'remotepath': '',
        'direction': 'PUSH',
        'delete': false,
        'enabled': true,
        'schedule': {
          'minute': '0',
          'hour': '0',
          'dom': '*',
          'month': '*',
          'dow': '0',
        },
        'job': null,
      },
    ],
  };

  final _finishedJobs = <int, Map<String, dynamic>>{};

  /// The one job `core.get_jobs` lists.
  static const runningScrub = {
    'id': 7,
    'method': 'pool.scrub.run',
    'state': 'RUNNING',
    'arguments': ['tank'],
    'progress': {'percent': 40, 'description': 'Scrubbing'},
    'abortable': true,
    'time_started': {r'$date': 1760000000000},
  };
  var _nextJobId = 100;

  /// Events passed to `core.subscribe`.
  final subscriptions = <String>[];

  /// Paths of WebSocket connections, e.g. `/api/v25.10.5`.
  final connectedPaths = <String>[];

  /// Refuse calls other than `auth.*` before login, like the middleware.
  bool requireLogin = false;

  final _apiSockets = <WebSocket>[];

  /// Closes every API connection, as a phone does to a backgrounded app.
  Future<void> dropConnections() async {
    final sockets = [..._apiSockets];
    _apiSockets.clear();
    for (final socket in sockets) {
      await socket.close();
    }
  }

  int get port => _server.port;

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    if (request.uri.path.startsWith('/icons/')) {
      // A 1×1 PNG, standing in for app catalog icons.
      request.response.headers.contentType = ContentType('image', 'png');
      request.response.add(base64Decode(_pixelPng));
      await request.response.close();
      return;
    }
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
      _apiSockets.add(socket);
      var awaitingOtp = false;
      var signedIn = false;
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
        if (requireLogin && !signedIn && !method.startsWith('auth.login')) {
          socket.add(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': message['id'],
              'error': {
                'code': -32001,
                'message': 'Method call error',
                'data': {
                  'error': 207,
                  'errname': 'ENOTAUTHENTICATED',
                  'reason': 'Not authenticated',
                },
              },
            }),
          );
          return;
        }
        if (method.startsWith('$snapshotService.')) {
          try {
            result = _snapshotCall(method.split('.').last, params);
          } on StateError catch (e) {
            socket.add(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': message['id'],
                'error': {
                  'code': -32001,
                  'message': 'Method call error',
                  'data': {'reason': '[EFAULT] ${e.message}'},
                },
              }),
            );
            return;
          }
        }
        final dot = method.lastIndexOf('.');
        if (dot > 0 && protection.containsKey(method.substring(0, dot))) {
          result = _protectionCall(
            method.substring(0, dot),
            method.substring(dot + 1),
            params,
          );
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
              signedIn = true;
              result = _success();
            }
          case 'auth.login_ex_continue':
            final data = params.first as Map<String, dynamic>;
            signedIn = awaitingOtp && data['otp_token'] == otp;
            result = signedIn ? _success() : {'response_type': 'AUTH_ERR'};
          case 'auth.me':
            result = {'pw_name': username};
          case 'system.info':
            result = {'hostname': 'nas', 'version': '25.10.7'};
          case 'core.subscribe':
            subscriptions.add(params.first as String);
            result = 'sub-${subscriptions.length}';
          case 'core.unsubscribe':
            result = null;
          case 'core.get_methods' when params.isEmpty:
            result = methodDocs;
          case 'core.get_methods':
            final service = params.first as String;
            result = <String, dynamic>{
              if (service == snapshotService)
                for (final m in [
                  'query',
                  'create',
                  'delete',
                  'rollback',
                  if (snapshotClone) 'clone',
                ])
                  '$service.$m': <String, dynamic>{},
              if (service == 'core') 'core.bulk': <String, dynamic>{},
              if (service == 'service' && !legacy)
                'service.control': <String, dynamic>{},
              if (service == 'nvmet.subsys' && !legacy)
                'nvmet.subsys.query': <String, dynamic>{},
              if (service == 'container' && !legacy)
                'container.query': <String, dynamic>{},
              if (service == 'virt.instance' && legacy)
                'virt.instance.query': <String, dynamic>{},
              if (protection.containsKey(service))
                '$service.query': <String, dynamic>{},
              if (service == 'update')
                for (final m
                    in legacy
                        ? ['check_available', 'update']
                        : ['status', 'run'])
                  'update.$m': <String, dynamic>{},
            };
          case 'keychaincredential.query':
            result = [
              {'id': 3, 'name': 'backup-box', 'type': 'SSH_CREDENTIALS'},
            ];
          case 'cloudsync.credentials.query':
            result = [
              {
                'id': 1,
                'name': 'Backblaze',
                'provider': {'type': 'B2'},
              },
            ];
          case 'service.query':
            result = services;
          case 'service.control':
            _setServiceState(params[1] as String, params[0] as String);
            result = _job();
          case 'service.start' || 'service.stop' || 'service.restart':
            _setServiceState(params[0] as String, method.split('.').last);
            result = true;
          case 'service.update':
            services.firstWhere((s) => s['id'] == params[0])['enable'] =
                (params[1] as Map)['enable'];
            result = params[0];
          case 'sharing.smb.query':
            result = smbShares;
          case 'sharing.smb.create':
            final data = params.first as Map<String, dynamic>;
            smbShares.add({
              'id': smbShares.length + 1,
              'enabled': true,
              'browsable': true,
              'locked': false,
              ...data,
            });
            result = smbShares.last;
          case 'sharing.smb.update':
            smbShares
                .firstWhere((s) => s['id'] == params[0])
                .addAll(params[1] as Map<String, dynamic>);
            result = true;
          case 'sharing.smb.delete':
            smbShares.removeWhere((s) => s['id'] == params[0]);
            result = true;
          case 'sharing.nfs.query':
            result = nfsShares;
          case 'sharing.nfs.create':
            final data = params.first as Map<String, dynamic>;
            nfsShares.add({
              'id': nfsShares.length + 1,
              'enabled': true,
              ...data,
            });
            result = nfsShares.last;
          case 'sharing.nfs.update':
            nfsShares
                .firstWhere((s) => s['id'] == params[0])
                .addAll(params[1] as Map<String, dynamic>);
            result = true;
          case 'sharing.nfs.delete':
            nfsShares.removeWhere((s) => s['id'] == params[0]);
            result = true;
          case 'app.container_console_choices':
            result = {
              'c0ffee': {
                'service_name': 'jellyfin',
                'image': 'jellyfin/jellyfin:10.10.7',
                'state': 'running',
                'id': 'c0ffee',
              },
            };
          case 'app.query':
            result = apps;
          case 'app.start' || 'app.stop' || 'app.redeploy' || 'app.upgrade':
            final app = apps.firstWhere((a) => a['name'] == params[0]);
            if (method == 'app.upgrade' &&
                failingUpgrades.contains(params[0])) {
              socket.add(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': message['id'],
                  'error': {
                    'code': -32001,
                    'message': 'Method call error',
                    'data': {'reason': '[EFAULT] Upgrade failed'},
                  },
                }),
              );
              return;
            }
            app['state'] = method == 'app.stop' ? 'STOPPED' : 'RUNNING';
            if (method == 'app.upgrade') {
              app['human_version'] = app['latest_version'];
              app['upgrade_available'] = false;
            }
            result = _job();
          case 'core.bulk':
            result = _bulk(params[0] as String, params[1] as List<dynamic>);
          case 'app.delete':
            apps.removeWhere((a) => a['name'] == params[0]);
            result = _job();
          case 'vm.query':
            result = vms;
          case 'vm.start' || 'vm.poweroff':
            (vms.firstWhere((v) => v['id'] == params[0])['status']
                as Map)['state'] = method == 'vm.start'
                ? 'RUNNING'
                : 'STOPPED';
            result = method == 'vm.start' ? null : true;
          case 'vm.stop' || 'vm.restart':
            (vms.firstWhere((v) => v['id'] == params[0])['status']
                as Map)['state'] = method == 'vm.stop'
                ? 'STOPPED'
                : 'RUNNING';
            result = _job();
          case 'container.query' || 'virt.instance.query':
            result = containers;
          case 'container.start':
            (containers.single['status'] as Map)['state'] = 'RUNNING';
            result = null;
          case 'container.stop':
            (containers.single['status'] as Map)['state'] = 'STOPPED';
            result = _job();
          case 'virt.instance.start' ||
              'virt.instance.stop' ||
              'virt.instance.restart':
            containers.single['status'] = method.endsWith('stop')
                ? 'STOPPED'
                : 'RUNNING';
            result = _job();
          case 'iscsi.target.query':
            result = [
              {'id': 1, 'name': 'vm', 'alias': 'VM disks', 'mode': 'ISCSI'},
            ];
          case 'iscsi.extent.query':
            result = [
              {
                'id': 1,
                'name': 'vm-disk',
                'type': 'DISK',
                'disk': 'zvol/tank/vm',
                'enabled': true,
                'ro': false,
              },
            ];
          case 'nvmet.subsys.query':
            result = [
              {
                'id': 1,
                'name': 'fast',
                'subnqn': 'nqn.2011-06.com.truenas:uuid:fast',
                'allow_any_host': false,
              },
            ];
          case 'user.query':
            final hideBuiltin = (params.first as List).length > 1;
            result = [
              for (final u in users)
                if (!hideBuiltin || u['builtin'] != true) u,
            ];
          case 'user.create':
            final data = params.first as Map<String, dynamic>;
            users.add({
              'id': 71,
              'uid': 3001,
              'username': data['username'],
              'full_name': data['full_name'],
              'builtin': false,
              'locked': false,
              'smb': data['smb'],
              'local': true,
            });
            result = 71;
          case 'user.update':
            users
                .firstWhere((u) => u['id'] == params.first)
                .addAll(params[1] as Map<String, dynamic>);
            result = params.first;
          case 'user.delete':
            users.removeWhere((u) => u['id'] == params.first);
            result = true;
          case 'group.query':
            // 25.04 orders in the database, where the column is `group`.
            final options = params.length > 1 ? asMapOrEmpty(params[1]) : {};
            if (legacy && '${options['order_by']}'.contains('name')) {
              socket.add(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': message['id'],
                  'error': {
                    'code': -32001,
                    'message': 'Method call error',
                    'data': {'reason': "'name'"},
                  },
                }),
              );
              return;
            }
            result = groups;
          case 'group.create':
            groups.add({
              'id': 41,
              'gid': 3001,
              'name': (params.first as Map)['name'],
              'builtin': false,
              'users': [],
              'local': true,
            });
            result = 41;
          case 'group.delete':
            groups.removeWhere((g) => g['id'] == params.first);
            result = true;
          case 'api_key.query':
            result = apiKeys;
          case 'api_key.create':
            final data = params.first as Map<String, dynamic>;
            apiKeys.add({
              'id': 2,
              'name': data['name'],
              'username': data['username'],
              'revoked': false,
            });
            result = {'id': 2, 'name': data['name'], 'key': '2-SECRETKEY'};
          case 'api_key.delete':
            apiKeys.removeWhere((k) => k['id'] == params.first);
            result = true;
          case 'network.general.summary':
            result = {
              'ips': {
                'enp1s0': {
                  'IPV4': ['192.168.1.10/24'],
                  'IPV6': ['fe80::1/64'],
                },
              },
              'default_routes': ['192.168.1.1'],
              'nameservers': ['1.1.1.1', '9.9.9.9'],
            };
          case 'network.configuration.config':
            result = {'hostname': 'nas', 'domain': 'local'};
          case 'interface.query':
            result = [
              {
                'id': 'enp1s0',
                'name': 'enp1s0',
                'type': 'PHYSICAL',
                'description': 'Onboard',
                'ipv4_dhcp': true,
                'state': {'link_state': 'LINK_STATE_UP', 'mtu': 1500},
              },
              {
                'id': 'enp2s0',
                'name': 'enp2s0',
                'type': 'PHYSICAL',
                'description': '',
                'ipv4_dhcp': false,
                'state': {'link_state': 'LINK_STATE_DOWN', 'mtu': 1500},
              },
            ];
          case 'certificate.query':
            result = [
              {
                'id': 1,
                'name': 'truenas_default',
                'common': 'localhost',
                'san': ['DNS:localhost'],
                'until': 'Tue Oct 13 08:00:00 2026',
                'expired': false,
              },
              {
                'id': 2,
                'name': 'old',
                'common': 'nas.example.com',
                'san': [],
                'until': 'Mon Jan  1 00:00:00 2024',
                'expired': true,
              },
            ];
          case 'update.status':
            result = {
              'code': 'NORMAL',
              'error': null,
              'status': {
                'current_version': {'version': '25.10.7'},
                'new_version': availableUpdate == null
                    ? null
                    : {
                        'version': availableUpdate,
                        'release_notes_url': 'https://example.com/notes',
                      },
              },
            };
          case 'update.check_available':
            result = availableUpdate == null
                ? {'status': 'UNAVAILABLE'}
                : {'status': 'AVAILABLE', 'version': availableUpdate};
          case 'update.run' || 'update.update':
            result = _job();
          case 'boot.environment.query':
            result = bootEnvironments;
          case 'boot.environment.activate':
            final id = (params.first as Map)['id'];
            for (final env in bootEnvironments) {
              env['activated'] = env['id'] == id;
            }
            result = true;
          case 'boot.environment.keep':
            final data = params.first as Map;
            bootEnvironments.firstWhere((e) => e['id'] == data['id'])['keep'] =
                data['value'];
            result = true;
          case 'boot.environment.destroy':
            final id = (params.first as Map)['id'];
            bootEnvironments.removeWhere((e) => e['id'] == id);
            result = null;
          case 'system.reboot' || 'system.shutdown':
            result = _job();
          case 'auth.generate_token':
            shellTokenParams = params;
            result = shellToken;
          case 'core.resize_shell':
            shellResizes.add(params);
          case 'test.fail':
            socket.add(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': message['id'],
                'error': {
                  'code': -32001,
                  'message': 'Method call error',
                  'data': {'reason': '[EINVAL] test.fail.name: Bad name'},
                },
              }),
            );
            return;
          case 'test.job':
            result = _job();
          case 'pool.query':
            result = pools;
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
          case 'alert.list_categories':
            result = alertCategories;
          case 'alert.dismiss' || 'alert.restore':
            final alert = alerts.firstWhere((a) => a['uuid'] == params.first);
            alert['dismissed'] = message['method'] == 'alert.dismiss';
          case 'core.get_jobs'
              when params.isNotEmpty &&
                  (params.first as List).isNotEmpty &&
                  ((params.first as List).first as List)[0] == 'state':
            // The jobs that are waiting or running.
            result = [runningScrub];
          case 'core.get_jobs'
              when params.isNotEmpty && (params.first as List).isNotEmpty:
            final filters = params.first as List;
            result = [
              for (final job in _finishedJobs.values.toList().reversed)
                if (filters.every((f) => job[(f as List)[0]] == f[2])) job,
            ];
          case 'core.get_jobs':
            result = [runningScrub];
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
    if (request.uri.path == '/websocket/shell/' &&
        WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      var connected = false;
      socket.listen((raw) {
        if (!connected) {
          final message = jsonDecode(raw as String) as Map<String, dynamic>;
          shellOptions = message['options'] as Map<String, dynamic>?;
          shellAttempts.add({...?shellOptions});
          if (shellDenied || message['token'] != shellToken) {
            socket.add(
              jsonEncode({
                'msg': 'failed',
                'error': {'error': 14, 'reason': 'Invalid token'},
              }),
            );
            return;
          }
          connected = true;
          socket.add(jsonEncode({'msg': 'connected', 'id': 'shell-1'}));
          final command = shellOptions?['command'] ?? '/bin/bash';
          if (missingShells.contains(command)) {
            socket.add(
              utf8.encode(
                'OCI runtime exec failed: exec failed: unable to start '
                'container process: exec: "$command": stat $command: no such '
                'file or directory: unknown\r\n',
              ),
            );
            socket.close();
            return;
          }
          socket.add(utf8.encode('truenas# '));
          return;
        }
        final input = utf8.decode(raw as List<int>);
        shellInput.write(input);
        socket.add(utf8.encode('you typed: $input'));
        if (input.contains('exit')) socket.close();
      });
      return;
    }
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  Object? _protectionCall(String service, String verb, List<dynamic> params) {
    final tasks = protection[service]!;
    switch (verb) {
      case 'query':
        return tasks;
      case 'update':
        tasks
            .firstWhere((t) => t['id'] == params.first)
            .addAll(params[1] as Map<String, dynamic>);
        return true;
      case 'delete':
        tasks.removeWhere((t) => t['id'] == params.first);
        return true;
      case 'create':
        tasks.add({
          'id': 99,
          ...params.first as Map<String, dynamic>,
          'state': {'state': 'PENDING'},
        });
        return 99;
      case 'run' || 'sync':
        return service == 'pool.snapshottask' ? null : _job();
      case 'abort':
        return true;
    }
    return null;
  }

  /// Runs [method] over [calls] as one job, as `core.bulk` does, and
  /// returns its id. See [holdBulk].
  int _bulk(String method, List<dynamic> calls) {
    bulkCalls.add((method, calls));
    final id = _nextJobId++;
    final job = <String, dynamic>{
      'id': id,
      'method': 'core.bulk',
      'arguments': [method, calls],
      'state': 'RUNNING',
      'progress': {'percent': 0, 'description': ''},
      'result': null,
    };
    _finishedJobs[id] = job;
    if (holdBulk) {
      _heldBulk.add(id);
    } else {
      _runBulk(job);
    }
    return id;
  }

  void _runBulk(Map<String, dynamic> job) {
    final method = (job['arguments'] as List)[0] as String;
    final calls = (job['arguments'] as List)[1] as List;
    job['result'] = [
      for (final call in calls)
        _applyToApp(method, (call as List).first as String)
            ? {'result': true, 'error': null}
            : {'result': null, 'error': '[EFAULT] Upgrade failed'},
    ];
    job['state'] = 'SUCCESS';
    job['progress'] = {'percent': 100, 'description': ''};
  }

  bool _applyToApp(String method, String name) {
    if (method == 'app.upgrade' && failingUpgrades.contains(name)) return false;
    final app = apps.firstWhere((a) => a['name'] == name);
    app['state'] = method == 'app.stop' ? 'STOPPED' : 'RUNNING';
    if (method == 'app.upgrade') {
      app['human_version'] = app['latest_version'];
      app['upgrade_available'] = false;
    }
    return true;
  }

  final _heldBulk = <int>[];

  /// Finishes the `core.bulk` jobs held by [holdBulk].
  void finishBulk() {
    for (final id in _heldBulk) {
      _runBulk(_finishedJobs[id]!);
    }
    _heldBulk.clear();
  }

  /// Records a finished job and returns its id.
  int _job() {
    final id = _nextJobId++;
    _finishedJobs[id] = {'id': id, 'state': 'SUCCESS', 'result': true};
    return id;
  }

  void _setServiceState(String service, String verb) {
    services.firstWhere((s) => s['service'] == service)['state'] =
        verb.toUpperCase() == 'STOP' ? 'STOPPED' : 'RUNNING';
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
      case 'rollback':
        final id = params.first as String;
        final options = params[1] as Map<String, dynamic>;
        final target = snapshots.firstWhere((s) => s['id'] == id);
        final newer = snapshots
            .where((s) => _created(s) > _created(target))
            .toList();
        if (newer.isNotEmpty && options['recursive'] != true) {
          throw StateError('more recent snapshots exist');
        }
        snapshots.removeWhere(newer.contains);
        return true;
      case 'clone':
        final data = params.first as Map<String, dynamic>;
        datasets.add(_dataset(data['dataset_dst'] as String, 0, 3000));
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

int _created(Map<String, dynamic> snapshot) =>
    (snapshot['properties']['creation']['parsed'][r'$date'] as int);

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

Map<String, dynamic> asMapOrEmpty(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

const _pixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
