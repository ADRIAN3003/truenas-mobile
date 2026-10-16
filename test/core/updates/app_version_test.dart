import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/updates/app_version.dart';

void main() {
  test('reads versions and release tags', () {
    expect(AppVersion.tryParse('0.1.3'), const AppVersion(0, 1, 3));
    expect(AppVersion.tryParse('v1.20.300'), const AppVersion(1, 20, 300));
    expect(AppVersion.tryParse(' v2.0.0 '), const AppVersion(2, 0, 0));
  });

  test('ignores a pre-release or build suffix', () {
    expect(AppVersion.tryParse('0.2.0-rc1'), const AppVersion(0, 2, 0));
    expect(AppVersion.tryParse('0.2.0+7'), const AppVersion(0, 2, 0));
  });

  test('rejects text that is not a version', () {
    expect(AppVersion.tryParse('nightly'), isNull);
    expect(AppVersion.tryParse('1.2'), isNull);
    expect(AppVersion.tryParse(''), isNull);
  });

  test('compares number by number, not as text', () {
    expect(
      AppVersion.tryParse('0.1.10')! > AppVersion.tryParse('0.1.9')!,
      true,
    );
    expect(
      AppVersion.tryParse('0.2.0')! > AppVersion.tryParse('0.1.99')!,
      true,
    );
    expect(
      AppVersion.tryParse('1.0.0')! > AppVersion.tryParse('0.99.99')!,
      true,
    );
    expect(
      AppVersion.tryParse('0.1.3')! > AppVersion.tryParse('0.1.3')!,
      false,
    );
    expect(AppVersion.tryParse('v0.1.3'), AppVersion.tryParse('0.1.3'));
  });

  test('prints without the v', () {
    expect(AppVersion.tryParse('v0.1.3').toString(), '0.1.3');
  });
}
