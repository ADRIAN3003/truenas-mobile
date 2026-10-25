import 'package:truenas_mobile/core/wol/wake_on_lan.dart';

/// Records the wake-ups instead of sending packets.
class FakeWakeOnLanSender implements WakeOnLanSender {
  final sent = <WakeOnLanSettings>[];

  /// When set, [wake] throws it.
  Object? failWith;

  @override
  Future<void> wake(WakeOnLanSettings settings) async {
    if (failWith != null) throw failWith!;
    sent.add(settings);
  }
}
