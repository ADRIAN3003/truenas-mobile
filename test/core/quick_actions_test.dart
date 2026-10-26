import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/api/workloads_api.dart';
import 'package:truenas_mobile/core/quick_actions/quick_actions.dart';

void main() {
  test('a shortcut survives the trip through the launcher', () {
    for (final kind in QuickActionKind.values) {
      final action = QuickAction(serverId: 'a', kind: kind, target: 'plex');
      expect(QuickAction.fromMap(action.toMap()), action);
    }
  });

  test('damaged shortcuts are ignored', () {
    expect(QuickAction.fromMap(null), isNull);
    expect(QuickAction.fromMap('x'), isNull);
    expect(QuickAction.fromMap({'serverId': 'a', 'kind': 'appStart'}), isNull);
    expect(
      QuickAction.fromMap({'serverId': '', 'kind': 'appStart', 'target': 'x'}),
      isNull,
    );
    expect(
      QuickAction.fromMap({'serverId': 'a', 'kind': 'nope', 'target': 'x'}),
      isNull,
    );
  });

  test('app shortcuts map to the app actions, a sync to none', () {
    expect(QuickActionKind.appStart.appAction, WorkloadAction.start);
    expect(QuickActionKind.appStop.appAction, WorkloadAction.stop);
    expect(QuickActionKind.appRestart.appAction, WorkloadAction.restart);
    expect(QuickActionKind.cloudSyncRun.appAction, isNull);
  });
}
