import 'json.dart';

/// One sample of the `reporting.realtime` event (sent every 2 seconds).
/// The shape is the same from 25.04 to 27.
class RealtimeStats {
  const RealtimeStats({
    required this.cpuPercent,
    required this.cpuTemperature,
    required this.memoryTotal,
    required this.memoryAvailable,
    required this.arcSize,
    required this.receivedBytesPerSecond,
    required this.sentBytesPerSecond,
  });

  factory RealtimeStats.fromJson(Map<String, dynamic> json) {
    final cpu = asMap(asMap(json['cpu'])['cpu']);
    final memory = asMap(json['memory']);
    var received = 0.0;
    var sent = 0.0;
    for (final value in asMap(json['interfaces']).values) {
      final interface = asMap(value);
      received += asDouble(interface['received_bytes_rate']);
      sent += asDouble(interface['sent_bytes_rate']);
    }
    final temperature = cpu['temp'];
    return RealtimeStats(
      cpuPercent: asDouble(cpu['usage']),
      cpuTemperature: temperature is num ? temperature.toDouble() : null,
      memoryTotal: asInt(memory['physical_memory_total']),
      memoryAvailable: asInt(memory['physical_memory_available']),
      arcSize: asInt(memory['arc_size']),
      receivedBytesPerSecond: received,
      sentBytesPerSecond: sent,
    );
  }

  /// Aggregate CPU usage across all cores, 0 to 100.
  final double cpuPercent;
  final double? cpuTemperature;
  final int memoryTotal;
  final int memoryAvailable;

  /// ZFS ARC size; part of "used" memory but released under pressure.
  final int arcSize;

  /// Summed across all interfaces.
  final double receivedBytesPerSecond;
  final double sentBytesPerSecond;

  int get memoryUsed => memoryTotal - memoryAvailable;
}
