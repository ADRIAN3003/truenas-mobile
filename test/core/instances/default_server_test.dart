import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/default_server.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';

ServerInstance _server(String id) => ServerInstance(
  id: id,
  name: 'NAS $id',
  url: 'https://$id.local',
  authMethod: AuthMethod.apiKey,
  username: 'truenas_admin',
  secret: 'key',
);

void main() {
  final a = _server('a');
  final b = _server('b');

  test('a single server is the default until the user says otherwise', () {
    expect(defaultServer([a], null), a);
    expect(defaultServer([a], noDefaultServer), isNull);
  });

  test('several servers have no default until one is chosen', () {
    expect(defaultServer([a, b], null), isNull);
    expect(defaultServer([a, b], 'b'), b);
    expect(defaultServer([a, b], noDefaultServer), isNull);
  });

  test('a chosen server that was deleted falls back like an unset one', () {
    expect(defaultServer([a, b], 'gone'), isNull);
    expect(defaultServer([a], 'gone'), a);
    expect(defaultServer(const [], null), isNull);
  });
}
