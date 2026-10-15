import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/models/alert.dart';
import 'package:truenas_mobile/core/models/job.dart';
import 'package:truenas_mobile/core/models/pool_summary.dart';
import 'package:truenas_mobile/core/models/realtime_stats.dart';

import '../../support/fake_truenas_server.dart';

void main() {
  test('realtime stats sum interfaces and read the CPU aggregate', () {
    final stats = RealtimeStats.fromJson(sampleRealtimeStats);
    expect(stats.cpuPercent, 23.5);
    expect(stats.cpuTemperature, 41.0);
    expect(stats.receivedBytesPerSecond, 125000);
    expect(stats.sentBytesPerSecond, 25000);
    expect(stats.memoryUsed, 12 * 1024 * 1024 * 1024);
  });

  test('realtime stats tolerate missing sections', () {
    final stats = RealtimeStats.fromJson(const {});
    expect(stats.cpuPercent, 0);
    expect(stats.cpuTemperature, isNull);
  });

  test('alerts parse levels, dates and strip HTML', () {
    final alert = TrueNasAlert.fromJson(const {
      'uuid': 'x',
      'level': 'CRITICAL',
      'formatted': 'Pool <b>tank</b> is degraded<br>Check disks &amp; cables',
      'dismissed': false,
      'datetime': {r'$date': 1760000000000},
    });
    expect(alert.level.severity, AlertSeverity.critical);
    expect(alert.plainMessage, 'Pool tank is degraded\nCheck disks & cables');
    expect(alert.time, DateTime.fromMillisecondsSinceEpoch(1760000000000));
    expect(AlertLevel.parse('WARNING').severity, AlertSeverity.warning);
    expect(AlertLevel.parse('NOTICE').severity, AlertSeverity.info);
  });

  test('jobs merge progress events', () {
    final job = TrueNasJob.fromJson(const {
      'id': 7,
      'method': 'pool.scrub.run',
      'state': 'RUNNING',
      'progress': {'percent': 10, 'description': 'Starting'},
      'abortable': true,
    });
    final updated = job.merge(const {
      'state': 'SUCCESS',
      'progress': {'percent': 100, 'description': 'Done'},
    });
    expect(updated.state, JobState.success);
    expect(updated.percent, 100);
    expect(updated.method, 'pool.scrub.run');
    expect(updated.abortable, isTrue);
    expect(job.title, 'pool.scrub.run');
  });

  test('pools report used fraction', () {
    final pool = PoolSummary.fromJson(const {
      'name': 'tank',
      'status': 'ONLINE',
      'healthy': true,
      'size': 4000,
      'allocated': 1000,
    });
    expect(pool.usedFraction, 0.25);
    expect(PoolSummary.fromJson(const {'name': 'x'}).usedFraction, 0);
  });
}
