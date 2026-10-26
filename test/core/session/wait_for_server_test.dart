import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/api/api_exception.dart';
import 'package:truenas_mobile/core/api/truenas_connection.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';
import 'package:truenas_mobile/core/session/wait_for_server.dart';

import '../../support/fake_truenas_server.dart';

const _fast = Duration(milliseconds: 5);

void main() {
  group('isStillStarting', () {
    test('connection trouble is worth another try', () {
      expect(isStillStarting(const SocketException('refused')), isTrue);
      expect(isStillStarting(TimeoutException('slow')), isTrue);
      expect(
        isStillStarting(const ApiException('Server answered 502')),
        isTrue,
      );
    });

    test('a refusal or a user decision is final', () {
      expect(isStillStarting(const LoginRejected('AUTH_ERR')), isFalse);
      expect(isStillStarting(const ConnectCancelled()), isFalse);
      expect(
        isStillStarting(const UnsupportedServerException(['v24.04'])),
        isFalse,
      );
    });
  });

  group('retryUntilOnline', () {
    test('tries again until the attempt works', () async {
      var tries = 0;
      final result = await retryUntilOnline(
        () async {
          if (++tries < 3) throw const SocketException('refused');
          return 'up';
        },
        token: WaitToken(),
        interval: _fast,
      );
      expect(result, 'up');
      expect(tries, 3);
    });

    test('a final error is thrown at once', () async {
      var tries = 0;
      await expectLater(
        retryUntilOnline<void>(
          () async {
            tries++;
            throw const LoginRejected('AUTH_ERR');
          },
          token: WaitToken(),
          interval: _fast,
        ),
        throwsA(isA<LoginRejected>()),
      );
      expect(tries, 1);
    });

    test('gives up when the time is out', () async {
      await expectLater(
        retryUntilOnline<void>(
          () async => throw const SocketException('refused'),
          token: WaitToken(),
          interval: _fast,
          timeout: const Duration(milliseconds: 30),
        ),
        throwsA(isA<ServerWaitTimeout>()),
      );
    });

    test('cancelling ends a wait that is sleeping', () async {
      final token = WaitToken();
      final run = retryUntilOnline<void>(
        () async => throw const SocketException('refused'),
        token: token,
        interval: const Duration(minutes: 5),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      token.cancel();
      await expectLater(run, throwsA(isA<ConnectCancelled>()));
    });
  });

  group('waitUntilDown', () {
    test('returns as soon as the server stops answering', () async {
      var answers = 3;
      await waitUntilDown(
        () async => --answers > 0,
        token: WaitToken(),
        interval: _fast,
      );
      expect(answers, 0);
    });

    test('a server that never goes down is not an error', () async {
      await waitUntilDown(
        () async => true,
        token: WaitToken(),
        interval: _fast,
        limit: const Duration(milliseconds: 30),
      );
    });
  });

  group('serverAnswers', () {
    setUp(() => HttpOverrides.global = null);

    ServerInstance at(int port) => ServerInstance(
      id: '1',
      name: 'Home',
      url: 'http://127.0.0.1:$port',
      authMethod: AuthMethod.password,
      username: 'truenas_admin',
      secret: 'secret',
    );

    test('is true while the server is up and false once it is gone', () async {
      final server = await FakeTrueNasServer.start();
      final instance = at(server.port);
      expect(await serverAnswers(instance), isTrue);
      await server.close();
      expect(await serverAnswers(instance), isFalse);
    });

    test('a server this app is too old for still answers', () async {
      final server = await FakeTrueNasServer.start(versions: ['v24.04']);
      expect(await serverAnswers(at(server.port)), isTrue);
      await server.close();
    });
  });
}
