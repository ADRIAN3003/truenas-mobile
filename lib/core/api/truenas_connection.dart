import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../logging/app_log.dart';
import 'api_exception.dart';
import 'api_version.dart';
import 'certificate_trust.dart';
import 'json_rpc_client.dart';
import 'server_address.dart';

/// Thrown when the server serves no API version this app supports.
class UnsupportedServerException implements Exception {
  const UnsupportedServerException(this.offered);

  final List<String> offered;

  @override
  String toString() => 'UnsupportedServerException($offered)';
}

/// An open, not yet authenticated, JSON-RPC connection to a TrueNAS server.
class TrueNasConnection {
  TrueNasConnection._(this.address, this.apiVersion, this.client, this._tls);

  final ServerAddress address;

  /// The API version in use, e.g. `v25.10.5`, or `current` when the server
  /// did not list its versions.
  final String apiVersion;
  final JsonRpcClient client;
  final PinningHttpClientFactory _tls;

  /// Opens another WebSocket on the same server, with the same certificate
  /// checks, e.g. `/_shell/` for the terminal.
  Future<WebSocketChannel> openSocket(
    String path, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final channel = IOWebSocketChannel.connect(
      address.socketUri(path),
      customClient: _tls.create(),
      pingInterval: const Duration(seconds: 30),
    );
    await channel.ready.timeout(timeout);
    return channel;
  }

  /// Picks the newest supported API version and opens its WebSocket.
  ///
  /// Throws [UntrustedCertificateException] when the certificate is not
  /// trusted and does not match [pinnedFingerprint],
  /// [UnsupportedServerException] for servers older than 25.04, and
  /// [ApiException] for anything else.
  static Future<TrueNasConnection> open(
    ServerAddress address, {
    String? pinnedFingerprint,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final tls = PinningHttpClientFactory(pinnedFingerprint: pinnedFingerprint);
    try {
      final version = await _negotiateVersion(address, tls, timeout);
      final channel = IOWebSocketChannel.connect(
        address.webSocketUri(version),
        customClient: tls.create(),
        pingInterval: const Duration(seconds: 30),
      );
      await channel.ready.timeout(timeout);
      return TrueNasConnection._(address, version, JsonRpcClient(channel), tls);
    } on UnsupportedServerException catch (error) {
      AppLog.instance.warning('connect', '${address.uri.host}: $error');
      rethrow;
    } on ApiException catch (error) {
      AppLog.instance.warning('connect', '${address.uri.host}: $error');
      rethrow;
    } catch (error) {
      final rejection = tls.rejection;
      // A certificate to confirm is a question for the user, not a failure.
      if (rejection != null) throw rejection;
      final failure = error is TimeoutException
          ? ApiException('Timed out connecting to ${address.uri.host}')
          : ApiException('Could not connect to ${address.uri.host}: $error');
      AppLog.instance.warning('connect', failure.toString());
      throw failure;
    }
  }

  static Future<String> _negotiateVersion(
    ServerAddress address,
    PinningHttpClientFactory tls,
    Duration timeout,
  ) async {
    final http = tls.create();
    try {
      final request = await http.getUrl(address.versionsUri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == HttpStatus.notFound) return 'current';
      if (response.statusCode != HttpStatus.ok) {
        throw ApiException(
          'Server answered ${response.statusCode}; is this a TrueNAS server?',
        );
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(body);
      } on FormatException {
        throw const ApiException('This does not look like a TrueNAS server');
      }
      if (decoded is! List) {
        throw const ApiException('This does not look like a TrueNAS server');
      }
      final offered = decoded.map((e) => e.toString()).toList();
      final selected = ApiVersion.selectNewest(offered);
      if (selected == null) throw UnsupportedServerException(offered);
      return selected;
    } finally {
      http.close(force: true);
    }
  }

  Future<void> close() => client.close();
}
