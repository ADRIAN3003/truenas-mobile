import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/wol/wake_on_lan.dart';

void main() {
  group('normalizeMac', () {
    test('accepts the usual spellings', () {
      for (final input in [
        'aa:bb:cc:dd:ee:ff',
        'AA-BB-CC-DD-EE-FF',
        'aabb.ccdd.eeff',
        ' aabbccddeeff ',
      ]) {
        expect(normalizeMac(input), 'AA:BB:CC:DD:EE:FF', reason: input);
      }
    });

    test('rejects anything else', () {
      for (final input in ['', 'aa:bb:cc', 'gg:bb:cc:dd:ee:ff', '1' * 13]) {
        expect(normalizeMac(input), isNull, reason: input);
      }
    });
  });

  test('the magic packet is six 0xFF bytes and the MAC sixteen times', () {
    final packet = magicPacket('01:02:03:04:05:06');
    expect(packet, hasLength(102));
    expect(packet.sublist(0, 6), everyElement(0xFF));
    for (var i = 0; i < 16; i++) {
      expect(packet.sublist(6 + i * 6, 12 + i * 6), [1, 2, 3, 4, 5, 6]);
    }
    expect(() => magicPacket('nope'), throwsFormatException);
  });

  test('the sender puts the packet on the wire', () async {
    final receiver = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(receiver.close);
    final received = <List<int>>[];
    receiver.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = receiver.receive();
        if (datagram != null) received.add(datagram.data);
      }
    });

    await const UdpWakeOnLanSender(repeats: 2).wake(
      WakeOnLanSettings(
        mac: 'AA:BB:CC:DD:EE:FF',
        broadcast: '127.0.0.1',
        port: receiver.port,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(received, hasLength(2));
    expect(received.first, magicPacket('AA:BB:CC:DD:EE:FF'));
  });

  group('settings in a saved server', () {
    const base = ServerInstance(
      id: 'a',
      name: 'NAS',
      url: 'https://nas.local',
      authMethod: AuthMethod.apiKey,
      username: 'truenas_admin',
      secret: 'key',
    );

    test('survive saving and loading', () {
      const wol = WakeOnLanSettings(
        mac: 'AA:BB:CC:DD:EE:FF',
        broadcast: '192.168.1.255',
        port: 7,
      );
      final copy = ServerInstance.fromJson(
        base.copyWith(wol: () => wol).toJson(),
      );
      expect(copy.wol, wol);
    });

    test('servers saved before the feature have none', () {
      expect(ServerInstance.fromJson(base.toJson()).wol, isNull);
      expect(base.toJson().containsKey('wol'), isFalse);
    });

    test('damaged data only loses the feature', () {
      for (final wol in <Object?>[
        'x',
        {},
        {'mac': 'nope'},
        3,
      ]) {
        final json = {...base.toJson(), 'wol': wol};
        expect(ServerInstance.fromJson(json).wol, isNull, reason: '$wol');
      }
      final json = {
        ...base.toJson(),
        'wol': {'mac': 'aabbccddeeff', 'broadcast': ' ', 'port': 'x'},
      };
      final wol = ServerInstance.fromJson(json).wol!;
      expect(wol.broadcast, defaultWolBroadcast);
      expect(wol.port, defaultWolPort);
    });
  });
}
