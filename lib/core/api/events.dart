import 'dart:async';

import 'json_rpc_client.dart';

/// A `collection_update` notification for a subscribed event.
class CollectionUpdate {
  const CollectionUpdate({
    required this.msg,
    required this.collection,
    this.id,
    this.fields,
  });

  factory CollectionUpdate.fromJson(Map<String, dynamic> json) =>
      CollectionUpdate(
        msg: (json['msg'] ?? '').toString(),
        collection: (json['collection'] ?? '').toString(),
        id: json['id'],
        fields: json['fields'] is Map<String, dynamic>
            ? json['fields'] as Map<String, dynamic>
            : null,
      );

  /// `added`, `changed` or `removed`.
  final String msg;
  final String collection;
  final Object? id;
  final Map<String, dynamic>? fields;
}

extension EventSubscriptions on JsonRpcClient {
  /// Subscribes to [event] (e.g. `reporting.realtime` or `alert.list`) with
  /// `core.subscribe` while the stream has a listener, and unsubscribes with
  /// `core.unsubscribe` when it is cancelled.
  Stream<CollectionUpdate> subscribe(String event) {
    final collection = event.split(':').first;
    late final StreamController<CollectionUpdate> controller;
    StreamSubscription<JsonRpcNotification>? notifications;
    Future<Object?>? subscription;

    controller = StreamController<CollectionUpdate>(
      onListen: () {
        notifications = this.notifications.listen((notification) {
          final params = notification.params;
          if (notification.method != 'collection_update' ||
              params is! Map<String, dynamic>) {
            return;
          }
          final update = CollectionUpdate.fromJson(params);
          if (update.collection == collection) controller.add(update);
        }, onDone: controller.close);
        subscription = call('core.subscribe', [event]);
        subscription!.catchError((Object error) {
          controller.addError(error);
          return null;
        });
      },
      onCancel: () async {
        await notifications?.cancel();
        final id = await subscription?.catchError((_) => null);
        if (id != null && !isClosed) {
          await call('core.unsubscribe', [id]).catchError((_) => null);
        }
      },
    );
    return controller.stream;
  }
}
