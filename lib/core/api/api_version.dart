/// A TrueNAS middleware API version such as `v25.04.2`, `v24.10` or `v27.0.0`.
///
/// Servers list the versions they serve at `GET /api/versions`, and each one is
/// reachable as a JSON-RPC WebSocket endpoint at `/api/<version>`.
class ApiVersion implements Comparable<ApiVersion> {
  const ApiVersion(this.major, this.minor, [this.patch = 0]);

  final int major;
  final int minor;
  final int patch;

  /// The oldest API version this app supports (TrueNAS 25.04).
  static const minimumSupported = ApiVersion(25, 4, 0);

  static final _pattern = RegExp(r'^v?(\d+)\.(\d+)(?:\.(\d+))?$');

  /// Parses `v25.04.2`, `25.04`, `v27.0.0`. Returns null for anything else.
  static ApiVersion? tryParse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) return null;
    return ApiVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3) ?? '0'),
    );
  }

  /// Picks the newest supported version from a `/api/versions` response.
  ///
  /// Returns null when the server offers nothing at or above
  /// [minimumSupported], which means the server is too old for this app.
  static String? selectNewest(Iterable<String> offered) {
    String? best;
    ApiVersion? bestVersion;
    for (final raw in offered) {
      final version = tryParse(raw);
      if (version == null || version < minimumSupported) continue;
      if (bestVersion == null || version > bestVersion) {
        best = raw;
        bestVersion = version;
      }
    }
    return best;
  }

  bool operator <(ApiVersion other) => compareTo(other) < 0;
  bool operator >(ApiVersion other) => compareTo(other) > 0;

  @override
  int compareTo(ApiVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  bool operator ==(Object other) =>
      other is ApiVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => 'v$major.${minor.toString().padLeft(2, '0')}.$patch';
}
