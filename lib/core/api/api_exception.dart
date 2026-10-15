/// An error returned by the TrueNAS middleware or raised by the client.
class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.data});

  /// Builds an exception from a JSON-RPC 2.0 `error` object.
  factory ApiException.fromJsonRpc(Map<String, dynamic> error) {
    final data = error['data'];
    var message = error['message']?.toString() ?? 'Unknown error';
    if (data is Map && data['reason'] is String) {
      message = data['reason'] as String;
    }
    return ApiException(message, code: error['code'] as int?, data: data);
  }

  final String message;
  final int? code;
  final Object? data;

  @override
  String toString() =>
      code == null ? 'ApiException: $message' : 'ApiException($code): $message';
}
