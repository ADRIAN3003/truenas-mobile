import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/logging/log_redaction.dart';

void main() {
  const apiKey =
      '1-AbCdEf0123456789AbCdEf0123456789AbCdEf0123456789AbCdEf012345678';

  test('removes values next to secret-looking names', () {
    for (final text in [
      'password: hunter2',
      'password=hunter2',
      '{"password":"hunter2"}',
      "{'secret': 'hunter2'}",
      'GET /x?token=hunter2&a=1',
      'api_key = hunter2',
      'apiKey: hunter2',
      'auth_token: hunter2',
      'private-key: hunter2',
      'Password: hunter2',
    ]) {
      final out = redactSecrets(text);
      expect(out, isNot(contains('hunter2')), reason: text);
      expect(out, contains('[redacted]'), reason: text);
    }
  });

  test('keeps the rest of the line', () {
    expect(
      redactSecrets('login failed, password: hunter2, user: admin'),
      'login failed, password: [redacted], user: admin',
    );
    expect(redactSecrets('a=1&token=zzz&b=2'), 'a=1&token=[redacted]&b=2');
  });

  test('removes bearer and basic credentials', () {
    expect(
      redactSecrets('Authorization: Bearer abc123def456'),
      'Authorization: Bearer [redacted]',
    );
    expect(redactSecrets('Basic dXNlcjpwYXNz'), 'Basic [redacted]');
  });

  test('removes the user info of a URL but keeps the host', () {
    expect(
      redactSecrets('wss://admin:hunter2@nas.local/api/current failed'),
      'wss://[redacted]@nas.local/api/current failed',
    );
  });

  test('removes a long key whatever it is called', () {
    final out = redactSecrets('rejected key $apiKey for admin');
    expect(out, 'rejected key [redacted] for admin');
  });

  test('leaves ordinary messages alone', () {
    for (final text in [
      'pool.query failed: ApiException(-32001): Not authenticated',
      'Could not connect to nas.local: SocketException: Connection refused',
      'Timed out connecting to 192.168.1.20',
      '/mnt/tank/media/some_quite_long_dataset_name_without_digits',
      'core_get_methods_for_the_whole_catalog_of_methods',
    ]) {
      expect(redactSecrets(text), text);
    }
  });
}
