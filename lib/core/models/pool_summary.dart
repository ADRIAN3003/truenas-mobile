import 'json.dart';

/// The parts of `pool.query` the dashboard shows.
class PoolSummary {
  const PoolSummary({
    required this.name,
    required this.status,
    required this.healthy,
    required this.size,
    required this.allocated,
  });

  factory PoolSummary.fromJson(Map<String, dynamic> json) => PoolSummary(
    name: (json['name'] ?? '').toString(),
    status: (json['status'] ?? 'UNKNOWN').toString(),
    healthy: json['healthy'] == true,
    size: asInt(json['size']),
    allocated: asInt(json['allocated']),
  );

  final String name;

  /// ZFS status such as `ONLINE` or `DEGRADED`.
  final String status;
  final bool healthy;
  final int size;
  final int allocated;

  double get usedFraction => size == 0 ? 0 : allocated / size;

  /// Needs attention when it is nearly full or not entirely healthy, and is
  /// down when ZFS says it is faulted or offline.
  PoolCondition get condition => switch (status.toUpperCase()) {
    'ONLINE' =>
      !healthy || usedFraction >= 0.9
          ? PoolCondition.attention
          : PoolCondition.ok,
    'DEGRADED' => PoolCondition.attention,
    _ => PoolCondition.down,
  };
}

enum PoolCondition { ok, attention, down }
