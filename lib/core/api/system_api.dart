import '../models/json.dart';
import '../models/system.dart';
import 'json_rpc_client.dart';
import 'method_catalog.dart';

/// Accounts, API keys, network, certificates, updates, boot environments
/// and power.
class SystemApi {
  SystemApi(this._client, this._catalog);

  final JsonRpcClient _client;
  final MethodCatalog _catalog;

  /// Recorded in the server's audit log for reboots and shutdowns.
  static const powerReason = 'Requested from TrueNAS Mobile';

  Future<List<Map<String, dynamic>>> _query(
    String method, [
    List<Object?> params = const [],
  ]) async => [
    for (final e in await _client.call(method, params) as List<dynamic>)
      asMap(e),
  ];

  // Users and groups

  /// Local users; built-in system accounts only when [builtin] is set.
  Future<List<LocalUser>> users({bool builtin = false}) async =>
      (await _query('user.query', [
        [
          ['local', '=', true],
          if (!builtin) ['builtin', '=', false],
        ],
        {
          'order_by': ['username'],
        },
      ])).map(LocalUser.fromJson).toList();

  /// Creates a user with a matching primary group.
  Future<void> createUser({
    required String username,
    required String fullName,
    required String password,
    bool smb = true,
  }) => _client.call('user.create', [
    {
      'username': username,
      'full_name': fullName,
      'password': password,
      'group_create': true,
      'smb': smb,
    },
  ]);

  Future<void> setUserLocked(int id, bool locked) =>
      _client.call('user.update', [
        id,
        {'locked': locked},
      ]);

  /// Deletes the user and its primary group if nothing else uses it.
  Future<void> deleteUser(int id) => _client.call('user.delete', [
    id,
    {'delete_group': true},
  ]);

  Future<List<LocalGroup>> groups({bool builtin = false}) async =>
      (await _query('group.query', [
        [
          ['local', '=', true],
          if (!builtin) ['builtin', '=', false],
        ],
        {
          'order_by': ['name'],
        },
      ])).map(LocalGroup.fromJson).toList();

  Future<void> createGroup(String name) => _client.call('group.create', [
    {'name': name},
  ]);

  Future<void> deleteGroup(int id) => _client.call('group.delete', [
    id,
    {'delete_users': false},
  ]);

  // API keys

  Future<List<ApiKeyInfo>> apiKeys() async =>
      (await _query('api_key.query')).map(ApiKeyInfo.fromJson).toList();

  /// Creates a key for [username] and returns the secret, which the server
  /// never shows again.
  Future<String> createApiKey(String name, String username) async {
    final result = asMap(
      await _client.call('api_key.create', [
        {'name': name, 'username': username},
      ]),
    );
    return (result['key'] ?? '').toString();
  }

  Future<void> deleteApiKey(int id) => _client.call('api_key.delete', [id]);

  // Network and certificates

  Future<NetworkSummary> networkSummary() async => NetworkSummary.fromJson(
    asMap(await _client.call('network.general.summary')),
  );

  Future<String?> hostname() async =>
      asMap(await _client.call('network.configuration.config'))['hostname']
          as String?;

  Future<List<NetInterface>> interfaces() async =>
      (await _query('interface.query')).map(NetInterface.fromJson).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  Future<List<CertificateInfo>> certificates() async =>
      (await _query('certificate.query'))
          .map(CertificateInfo.fromJson)
          .toList();

  // Updates, boot environments, power

  /// `update.status` on 25.10 and newer, `update.check_available` on 25.04.
  Future<UpdateInfo> checkForUpdate() async {
    if (await _catalog.has('update.status')) {
      return UpdateInfo.fromStatus(asMap(await _client.call('update.status')));
    }
    return UpdateInfo.fromCheck(
      asMap(await _client.call('update.check_available')),
    );
  }

  /// Downloads and applies the update, then reboots. Returns the job id;
  /// the connection drops when the server restarts.
  Future<int> applyUpdate() async {
    final method = await _catalog.has('update.run')
        ? 'update.run'
        : 'update.update';
    return asInt(
      await _client.call(method, [
        {'reboot': true},
      ]),
    );
  }

  Future<List<BootEnvironment>> bootEnvironments() async =>
      (await _query('boot.environment.query'))
          .map(BootEnvironment.fromJson)
          .toList()
        ..sort(
          (a, b) =>
              (b.created ?? DateTime(0)).compareTo(a.created ?? DateTime(0)),
        );

  /// Boots into [id] next time.
  Future<void> activateBootEnvironment(String id) =>
      _client.call('boot.environment.activate', [
        {'id': id},
      ]);

  Future<void> keepBootEnvironment(String id, bool keep) =>
      _client.call('boot.environment.keep', [
        {'id': id, 'value': keep},
      ]);

  Future<void> deleteBootEnvironment(String id) =>
      _client.call('boot.environment.destroy', [
        {'id': id},
      ]);

  /// Starts a reboot. Doesn't wait: the server goes away.
  Future<void> reboot() => _client.call('system.reboot', [powerReason]);

  /// Starts a shutdown. Doesn't wait: the server goes away.
  Future<void> shutdown() => _client.call('system.shutdown', [powerReason]);
}
