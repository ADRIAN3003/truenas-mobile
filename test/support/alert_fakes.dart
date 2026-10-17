import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/models/alert.dart';
import 'package:truenas_mobile/core/notifications/alert_watcher.dart';
import 'package:truenas_mobile/core/notifications/background_alerts.dart';

/// The phone's notifications, without a phone.
class FakeAlertNotifier implements AlertNotifier {
  FakeAlertNotifier({this.allowed = true});

  /// Whether the user allows notifications.
  bool allowed;
  int permissionRequests = 0;

  /// Every notification shown, as `server: id1,id2`.
  final shown = <String>[];

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allowed;
  }

  @override
  Future<void> show(ServerInstance server, List<TrueNasAlert> alerts) async {
    shown.add('${server.name}: ${alerts.map((a) => a.id).join(',')}');
  }
}

/// The phone's background scheduler, without a phone.
class FakeBackgroundScheduler implements BackgroundScheduler {
  bool scheduled = false;
  int scheduleCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<void> schedule() async {
    scheduled = true;
    scheduleCalls++;
  }

  @override
  Future<void> cancel() async => scheduled = false;
}

/// A `alert.list` entry as the server sends it.
Map<String, dynamic> alertJson(
  String uuid, {
  String level = 'CRITICAL',
  String text = 'Something happened',
  bool dismissed = false,
  String klass = 'Test',
}) => {
  'uuid': uuid,
  'level': level,
  'klass': klass,
  'formatted': text,
  'dismissed': dismissed,
  'datetime': {r'$date': 1760000000000},
};
