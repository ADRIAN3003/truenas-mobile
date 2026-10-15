import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';

import 'api_exception.dart';
import 'json_rpc_client.dart';

/// A terminal on the server through the `/websocket/shell/` WebSocket, the
/// same one the web UI uses.
///
/// The protocol: get a one-time token with `auth.generate_token`, open the
/// socket, send `{"token": ..., "options": {...}}`, and wait for
/// `{"msg": "connected", "id": ...}`. After that, input goes up as binary
/// frames and output comes back as binary frames. Resizing is a separate
/// JSON-RPC call, `core.resize_shell(id, cols, rows)`.
class ShellSession {
  ShellSession._(this._client, this._channel, this.id, this._incoming);

  final JsonRpcClient _client;
  final StreamChannel<dynamic> _channel;
  final StreamQueue<dynamic> _incoming;

  /// The server's id for this shell, used for resizing.
  final String id;

  /// Connects using [openSocket] (the session's `openSocket(shellPath)`).
  /// [options] picks something other than the host shell, e.g.
  /// `{'vm_id': 1}`.
  static Future<ShellSession> open(
    JsonRpcClient client,
    Future<StreamChannel<dynamic>> Function() openSocket, {
    Map<String, Object?> options = const {},
    Duration timeout = const Duration(seconds: 20),
  }) async {
    // ttl, attrs, match_origin, single_use
    final token = await client.call('auth.generate_token', [
      300,
      <String, Object?>{},
      true,
      true,
    ]);
    final channel = await openSocket();
    final incoming = StreamQueue<dynamic>(channel.stream);
    channel.sink.add(jsonEncode({'token': token, 'options': options}));
    try {
      while (true) {
        final first = await incoming.next.timeout(timeout);
        if (first is! String) continue;
        final Object? message;
        try {
          message = jsonDecode(first);
        } on FormatException {
          continue;
        }
        if (message is! Map) continue;
        switch (message['msg']) {
          case 'connected':
            return ShellSession._(
              client,
              channel,
              message['id'].toString(),
              incoming,
            );
          case 'failed':
            final error = message['error'];
            throw ApiException(
              error is Map && error['reason'] != null
                  ? error['reason'].toString()
                  : 'The server refused the shell',
            );
        }
      }
    } on TimeoutException {
      await channel.sink.close();
      throw const ApiException('The shell did not start');
    } on StateError {
      throw const ApiException('The server closed the shell');
    } catch (_) {
      await channel.sink.close();
      rethrow;
    }
  }

  /// Raw terminal output.
  Stream<List<int>> get output async* {
    while (await _incoming.hasNext) {
      final data = await _incoming.next;
      if (data is List<int>) {
        yield data;
      } else if (data is String) {
        yield utf8.encode(data);
      }
    }
  }

  /// Sends keystrokes or pasted text.
  void write(String data) => _channel.sink.add(utf8.encode(data));

  /// Tells the server the terminal's new size. Failures are ignored: an
  /// unresized terminal still works.
  Future<void> resize(int cols, int rows) async {
    try {
      await _client.call('core.resize_shell', [id, cols, rows]);
    } catch (_) {}
  }

  Future<void> close() async {
    await _channel.sink.close();
  }
}
