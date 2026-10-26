import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The server whose alert notification the user tapped, until the app has
/// opened it. Null when there is none.
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
