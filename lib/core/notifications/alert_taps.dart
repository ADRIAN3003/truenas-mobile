import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a finished-job notification carries in front of the server id, so that
/// a tap opens the server and not its alerts.
const jobPayloadPrefix = 'job:';

/// The notification the user tapped (a server id, or [jobPayloadPrefix] and
/// one), until the app has opened it. Null when there is none.
class PendingAlertServer extends Notifier<String?> {
  @override
  String? build() => ref.watch(launchAlertServerProvider);

  void open(String serverId) => state = serverId;

  void clear() => state = null;
}

final pendingAlertServerProvider =
    NotifierProvider<PendingAlertServer, String?>(PendingAlertServer.new);

/// The server of the notification that started the app, if one did. `main`
/// reads it from the phone before the first frame.
final launchAlertServerProvider = Provider<String?>((ref) => null);
