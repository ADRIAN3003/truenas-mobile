import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:truenas_mobile/core/api/events.dart';
import 'package:truenas_mobile/core/api/json_rpc_client.dart';

void main() {
  test('subscribes, filters by collection and unsubscribes', () async {
    final controller = StreamChannelController<dynamic>();
    final client = JsonRpcClient(controller.local);
    final sent = <Map<String, dynamic>>[];
    controller.foreign.stream.listen((raw) {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      sent.add(message);
      controller.foreign.sink.add(
        jsonEncode({'jsonrpc': '2.0', 'id': message['id'], 'result': 'sub-1'}),
      );
    });
    void push(String collection) => controller.foreign.sink.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'method': 'collection_update',
        'params': {
          'msg': 'added',
          'collection': collection,
          'fields': {'value': collection},
        },
      }),
    );

    final updates = <CollectionUpdate>[];
    final subscription = client
        .subscribe('reporting.realtime')
        .listen(updates.add);
    await pumpEventQueue();
    expect(sent.single['method'], 'core.subscribe');
    expect(sent.single['params'], ['reporting.realtime']);

    push('alert.list');
    push('reporting.realtime');
    await pumpEventQueue();
    expect(updates.single.fields, {'value': 'reporting.realtime'});

    await subscription.cancel();
    await pumpEventQueue();
    expect(sent.last['method'], 'core.unsubscribe');
    expect(sent.last['params'], ['sub-1']);
  });
}
