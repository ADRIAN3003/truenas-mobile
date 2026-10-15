import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/api/server_address.dart';

void main() {
  test('assumes https and strips paths', () {
    final address = ServerAddress.tryParse(' nas.local/ui/dashboard ')!;
    expect(address.toString(), 'https://nas.local');
    expect(address.isSecure, isTrue);
  });

  test('keeps ports and plain http', () {
    final address = ServerAddress.tryParse('http://192.168.1.10:8080')!;
    expect(address.isSecure, isFalse);
    expect(
      address.webSocketUri('v25.10.5').toString(),
      'ws://192.168.1.10:8080/api/v25.10.5',
    );
    expect(
      address.versionsUri.toString(),
      'http://192.168.1.10:8080/api/versions',
    );
  });

  test('uses wss for https', () {
    expect(
      ServerAddress.tryParse('nas.local')!.webSocketUri('current').toString(),
      'wss://nas.local:443/api/current',
    );
  });

  test('spells out the default port for sockets', () {
    final address = ServerAddress.tryParse('https://truenas.example.com')!;
    expect(
      address.socketUri('/websocket/shell/').toString(),
      'wss://truenas.example.com:443/websocket/shell/',
    );
  });

  test('rejects empty input and other schemes', () {
    expect(ServerAddress.tryParse(''), isNull);
    expect(ServerAddress.tryParse('ftp://nas.local'), isNull);
  });
}
