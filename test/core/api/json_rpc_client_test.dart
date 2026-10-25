import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:truenas_mobile/core/api/api_exception.dart';
import 'package:truenas_mobile/core/api/json_rpc_client.dart';
import 'package:truenas_mobile/core/logging/app_log.dart';

void main() {
  late StreamChannelController<dynamic> controller;
  late JsonRpcClient client;
  late List<Map<String, dynamic>> sent;

  setUp(() {
    AppLog.instance = AppLog();
    controller = StreamChannelController<dynamic>();
    client = JsonRpcClient(controller.local);
    sent = [];
    controller.foreign.stream.listen(
      (raw) => sent.add(jsonDecode(raw as String) as Map<String, dynamic>),
    );
  });

  void reply(Map<String, dynamic> message) =>
      controller.foreign.sink.add(jsonEncode({'jsonrpc': '2.0', ...message}));

  test('sends a JSON-RPC request and returns the result', () async {
    final future = client.call('system.info');
    await pumpEventQueue();
    expect(sent.single['method'], 'system.info');
    expect(sent.single['params'], isEmpty);

    reply({
      'id': sent.single['id'],
      'result': {'version': '25.10.7'},
    });
    expect(await future, {'version': '25.10.7'});
  });

  test('maps error replies to ApiException using the reason', () async {
    final future = client.call('pool.query');
    await pumpEventQueue();
    reply({
      'id': sent.single['id'],
      'error': {
        'code': -32001,
        'message': 'Method call error',
        'data': {'reason': 'Not authenticated'},
      },
    });
    await expectLater(
      future,
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'Not authenticated')
            .having((e) => e.code, 'code', -32001),
      ),
    );
  });

  test('logs a refused call without its parameters', () async {
    final future = client.call('auth.login_ex', [
      {'username': 'root', 'password': 'hunter2'},
    ]);
    await pumpEventQueue();
    reply({
      'id': sent.single['id'],
      'error': {'code': 13, 'message': 'Bad password'},
    });
    await expectLater(future, throwsA(isA<ApiException>()));
    final entry = AppLog.instance.entries.single;
    expect(entry.level, LogLevel.warning);
    expect(entry.source, 'rpc');
    expect(entry.message, contains('auth.login_ex failed'));
    expect(entry.message, contains('Bad password'));
    expect(entry.message, isNot(contains('hunter2')));
  });

  test('logs a call that times out', () async {
    final slow = JsonRpcClient(
      StreamChannelController<dynamic>().local,
      timeout: const Duration(milliseconds: 20),
    );
    await expectLater(slow.call('pool.scrub'), throwsA(isA<ApiException>()));
    expect(
      AppLog.instance.entries.single.message,
      contains('pool.scrub failed'),
    );
  });

  test('forwards notifications', () async {
    final next = client.notifications.first;
    reply({
      'method': 'collection_update',
      'params': {'collection': 'alert.list'},
    });
    final notification = await next;
    expect(notification.method, 'collection_update');
  });

  test('fails pending calls when the connection closes', () async {
    final future = client.call('system.info');
    await pumpEventQueue();
    await controller.foreign.sink.close();
    await expectLater(future, throwsA(isA<ApiException>()));
    expect(client.isClosed, isTrue);
  });
}
