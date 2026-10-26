import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/models/alert.dart';
import 'package:truenas_mobile/core/models/pool_summary.dart';
import 'package:truenas_mobile/core/overview/server_overview.dart';

PoolSummary pool(String status, {bool healthy = true, int allocated = 100}) =>
    PoolSummary(
      name: 'tank',
      status: status,
      healthy: healthy,
      size: 1000,
      allocated: allocated,
    );

TrueNasAlert alert(AlertLevel level) => TrueNasAlert(
  id: level.name,
  level: level,
  message: 'm',
  klass: 'k',
  dismissed: false,
);

ServerSnapshot snapshot({
  List<PoolSummary> pools = const [],
  List<TrueNasAlert> alerts = const [],
}) => ServerSnapshot(pools: pools, alerts: alerts, jobs: const []);

void main() {
  test('a healthy server with no alerts is ok', () {
    expect(snapshot(pools: [pool('ONLINE')]).level, OverviewLevel.ok);
    expect(snapshot().level, OverviewLevel.ok);
  });

  test('a degraded or nearly full pool and a warning need attention', () {
    expect(snapshot(pools: [pool('DEGRADED')]).level, OverviewLevel.attention);
    expect(
      snapshot(pools: [pool('ONLINE', allocated: 950)]).level,
      OverviewLevel.attention,
    );
    expect(
      snapshot(alerts: [alert(AlertLevel.warning)]).level,
      OverviewLevel.attention,
    );
    // Information is not a reason to look.
    expect(snapshot(alerts: [alert(AlertLevel.info)]).level, OverviewLevel.ok);
  });

  test('a down pool or a critical alert is a problem', () {
    expect(snapshot(pools: [pool('FAULTED')]).level, OverviewLevel.problem);
    expect(
      snapshot(alerts: [alert(AlertLevel.critical)]).level,
      OverviewLevel.problem,
    );
  });
}
