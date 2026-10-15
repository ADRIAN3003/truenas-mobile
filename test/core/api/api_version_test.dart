import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/api/api_version.dart';

void main() {
  test('parses two- and three-part versions', () {
    expect(ApiVersion.tryParse('v25.04.2'), const ApiVersion(25, 4, 2));
    expect(ApiVersion.tryParse('v24.10'), const ApiVersion(24, 10));
    expect(ApiVersion.tryParse('27.0.0'), const ApiVersion(27, 0));
    expect(ApiVersion.tryParse('current'), isNull);
  });

  test('selects the newest supported version, as served by 27.0.0-RC.1', () {
    const offered = [
      'v24.10', 'v25.04.0', 'v25.04.1', 'v25.04.2', //
      'v25.10.0', 'v25.10.5', 'v27.0.0',
    ];
    expect(ApiVersion.selectNewest(offered), 'v27.0.0');
  });

  test('handles the old YY.MM numbering on 25.04 servers', () {
    expect(
      ApiVersion.selectNewest(['v24.10', 'v25.04.0', 'v25.04.2']),
      'v25.04.2',
    );
  });

  test('rejects servers older than 25.04', () {
    expect(ApiVersion.selectNewest(['v24.10']), isNull);
  });
}
