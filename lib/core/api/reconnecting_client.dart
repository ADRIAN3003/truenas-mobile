import 'dart:async';

import 'api_exception.dart';
import 'json_rpc_client.dart';

/// Opens a new connection and signs in, returning its client.
typedef Reconnect = Future<JsonRpcClient> Function();

/// A [JsonRpcClient] that outlives its socket.
///
/// Phones drop WebSockets while the app is in the background or the screen
/// is locked, and TrueNAS ties the login to the socket. When the socket is
/// gone, the next call opens a new one and signs in again through
/// [Reconnect] before it is sent; [reconnected] then fires so event
/// subscriptions can be renewed. Calls are never resent once they reached
/// the server, so nothing runs twice.
class ReconnectingJsonRpcClient implements JsonRpcClient {
  ReconnectingJsonRpcClient(this._current, this._reconnect) {
    _forward(_current);
  }

  JsonRpcClient _current;
  final Reconnect _reconnect;
  final _notifications = StreamController<JsonRpcNotification>.broadcast();
  final _reconnected = StreamController<void>.broadcast();
  StreamSubscription<JsonRpcNotification>? _forwarding;
  Future<void>? _reconnecting;
  var _closed = false;

  /// The client of the socket in use right now.
  JsonRpcClient get current => _current;

  @override
  Duration get timeout => _current.timeout;

  @override
  Stream<JsonRpcNotification> get notifications => _notifications.stream;

  @override
  Stream<void> get reconnected => _reconnected.stream;

  @override
  bool get isClosed => _closed;

  @override
  Future<Object?> call(String method, [List<Object?> params = const []]) async {
    if (_closed) throw const ApiException('Connection is closed');
    if (_reconnecting != null || _current.isClosed) await reconnect();
    try {
      return await _current.call(method, params);
    } on ApiException catch (error) {
      // The server dropped the login but kept the socket: the call was
      // refused before it ran, so sign in again and send it once more.
      if (!_isNotAuthenticated(error)) rethrow;
      await reconnect();
      return _current.call(method, params);
    }
  }

  /// Checks that the connection still answers, as after the app comes back
  /// from the background, and reconnects when it does not.
  Future<void> ensureAlive({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_closed) return;
    if (_reconnecting != null) return _reconnecting;
    if (!_current.isClosed) {
      try {
        // Needs a login, so an expired session counts as dead too.
        await _current.call('auth.me').timeout(timeout);
        return;
      } catch (_) {}
    }
    await reconnect();
  }

  /// Replaces the socket with a new, signed-in one. Concurrent callers share
  /// one attempt.
  Future<void> reconnect() =>
      _reconnecting ??= _replace().whenComplete(() => _reconnecting = null);

  Future<void> _replace() async {
    final previous = _current;
    await _forwarding?.cancel();
    unawaited(previous.close().catchError((_) {}));
    final next = await _reconnect();
    if (_closed) {
      await next.close();
      throw const ApiException('Connection is closed');
    }
    _current = next;
    _forward(next);
    _reconnected.add(null);
  }

  void _forward(JsonRpcClient client) {
    _forwarding = client.notifications.listen(_notifications.add);
  }

  static bool _isNotAuthenticated(ApiException error) {
    final data = error.data;
    if (data is Map && data['errname'] == 'ENOTAUTHENTICATED') return true;
    return error.message.toLowerCase().contains('not authenticated');
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _forwarding?.cancel();
    await _notifications.close();
    await _reconnected.close();
    await _current.close();
  }
}
