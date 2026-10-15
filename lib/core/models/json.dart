// Helpers for decoding middleware JSON leniently, so small differences
// between TrueNAS versions do not break the app.

double asDouble(Object? value) => value is num ? value.toDouble() : 0;

int asInt(Object? value) => value is num ? value.toInt() : 0;

Map<String, dynamic> asMap(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

/// Middleware dates arrive as `{"$date": <epoch ms>}`.
DateTime? asDate(Object? value) {
  final millis = value is Map ? value[r'$date'] : value;
  return millis is num
      ? DateTime.fromMillisecondsSinceEpoch(millis.toInt())
      : null;
}
