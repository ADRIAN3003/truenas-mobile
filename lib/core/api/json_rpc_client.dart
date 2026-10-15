import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';

import 'api_exception.dart';

/// A server-initiated JSON-RPC notification, such as `collection_update`.
class JsonRpcNotification {
  const JsonRpcNotification(this.method, this.params);

  final String method;
  final Object? params;
}

/// Minimal JSON-RPC 2.0 client over a WebSocket, as served by TrueNAS at
/// `wss://<host>/api/<version>`. Pass a `WebSocketChannel` in production.
class JsonRpcClient {
  JsonRpcClient(this._channel, {this.timeout = const Duration(seconds: 60)}) {
    _subscription = _channel.stream.listen(
      _onMessage,
      onError: _onDone,
      onDone: () => _onDone(null),
    );
  }

  final StreamChannel<dynamic> _channel;
  final Duration timeout;
  late final StreamSubscription<dynamic> _subscription;

  final _pending = <int, Completer<Object?>>{};
  final _notifications = StreamController<JsonRpcNotification>.broadcast();
  var _nextId = 1;
  var _closed = false;

  /// Notifications pushed by the server (events, job updates).
  Stream<JsonRpcNotification> get notifications => _notifications.stream;

  bool get isClosed => _closed;

  /// Fires after a dropped connection was restored and signed in again, so
  /// event subscriptions can be renewed. A plain socket never reconnects.
  Stream<void> get reconnected => const Stream.empty();

  /// Calls [method] with positional [params] and returns its `result`.
  Future<Object?> call(String method, [List<Object?> params = const []]) {
    if (_closed) {
      return Future.error(const ApiException('Connection is closed'));
    }
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _channel.sink.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      }),
    );
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(id);
        throw ApiException('Call to $method timed out');
      },
    );
  }

  Future<void> close() async {
    _onDone(null);
    await _subscription.cancel();
    await _channel.sink.close();
  }

  void _onMessage(dynamic raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw as String);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;

    final id = decoded['id'];
    if (id == null) {
      final method = decoded['method'];
      if (method is String) {
        _notifications.add(JsonRpcNotification(method, decoded['params']));
      }
      return;
    }

    final completer = _pending.remove(id);
    if (completer == null) return;
    final error = decoded['error'];
    if (error is Map<String, dynamic>) {
      completer.completeError(ApiException.fromJsonRpc(error));
    } else {
      completer.complete(decoded['result']);
    }
  }

  void _onDone(Object? error) {
    if (_closed) return;
    _closed = true;
    final failure = ApiException(
      error == null ? 'Connection closed' : 'Connection lost: $error',
    );
    for (final completer in _pending.values) {
      completer.completeError(failure);
    }
    _pending.clear();
    _notifications.close();
  }
}
