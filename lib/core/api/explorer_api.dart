import '../models/api_method.dart';
import '../models/json.dart';
import 'job_wait.dart';
import 'json_rpc_client.dart';

/// Generic access to every method the server offers, for the API explorer.
class ExplorerApi {
  ExplorerApi(this._client);

  final JsonRpcClient _client;
  Future<List<ApiMethod>>? _methods;

  /// Every method this user may call, sorted by name. Fetched once per
  /// connection; [refresh] fetches again.
  Future<List<ApiMethod>> methods({bool refresh = false}) {
    if (refresh) _methods = null;
    return _methods ??= _fetch().catchError((Object error) {
      _methods = null;
      throw error;
    });
  }

  Future<List<ApiMethod>> _fetch() async {
    final result = asMap(await _client.call('core.get_methods'));
    return [
      for (final MapEntry(:key, :value) in result.entries)
        ApiMethod.fromJson(key, asMap(value)),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Calls [method]. Jobs are followed until they finish, and their result
  /// is returned; [onJobStarted] gets the job id first.
  Future<Object?> run(
    ApiMethod method,
    List<Object?> params, {
    void Function(int jobId)? onJobStarted,
  }) async {
    final result = await _client.call(method.name, params);
    if (!method.job || result is! int) return result;
    onJobStarted?.call(result);
    return waitForJob(_client, result, timeout: const Duration(hours: 1));
  }
}
