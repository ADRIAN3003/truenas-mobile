import 'json_rpc_client.dart';

/// Finds out which API methods a server offers, one service at a time,
/// with `core.get_methods(service)`. Results are cached per connection.
///
/// Screens use this instead of version numbers, because namespaces move
/// between releases (for example `zfs.snapshot` in 25.04 became
/// `pool.snapshot` in 25.10).
class MethodCatalog {
  MethodCatalog(this._client);

  final JsonRpcClient _client;
  final _services = <String, Future<Set<String>>>{};

  Future<Set<String>> methodsOf(String service) =>
      _services.putIfAbsent(service, () async {
        try {
          final result = await _client.call('core.get_methods', [service]);
          return result is Map ? result.keys.cast<String>().toSet() : {};
        } catch (_) {
          return <String>{};
        }
      });

  /// Whether `service.method` exists, e.g. `pool.snapshot.query`.
  Future<bool> has(String method) async {
    final service = method.substring(0, method.lastIndexOf('.'));
    return (await methodsOf(service)).contains(method);
  }

  /// The first service in [candidates] that has [method].
  Future<String?> firstWith(List<String> candidates, String method) async {
    for (final service in candidates) {
      if (await has('$service.$method')) return service;
    }
    return null;
  }
}
