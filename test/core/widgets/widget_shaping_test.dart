import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/models/alert.dart';
import 'package:truenas_mobile/core/models/job.dart';
import 'package:truenas_mobile/core/models/pool_summary.dart';
import 'package:truenas_mobile/core/models/realtime_stats.dart';
import 'package:truenas_mobile/core/models/workloads.dart';
import 'package:truenas_mobile/core/widgets/home_widget_data.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

/// The iOS widgets shape the server's answers themselves, in Swift
/// (`WidgetShape` in `ios/JobActivityWidget/WidgetFetch.swift`), the way
/// `serverWidgetData` does here. Both are held to the same file: the raw
/// answers and the JSON that must come out of them. The Swift side is checked
/// by `tools/check-widget-shaping.sh` on the macOS CI job.
///
/// After changing the shaping on purpose, rewrite the expected JSON with
/// `UPDATE_WIDGET_FIXTURE=1 flutter test test/core/widgets/widget_shaping_test.dart`
/// and make the Swift side produce it.
const _fixturePath = 'test/fixtures/widget_shaping.json';

/// [value] without the nulls: Dart writes `"percent": null`, Swift leaves the
/// key out.
Object? _withoutNulls(Object? value) => switch (value) {
  Map() => {
    for (final entry in value.entries)
      if (entry.value != null) entry.key: _withoutNulls(entry.value),
  },
  List() => [for (final item in value) _withoutNulls(item)],
  _ => value,
};

List<Map<String, dynamic>> _rows(Object? list) => [
  for (final row in list as List<dynamic>) row as Map<String, dynamic>,
];

Map<String, dynamic> _shape(Map<String, dynamic> raw, AppLocalizations l10n) {
  final realtime = raw['realtime'] as Map<String, dynamic>?;
  final data = serverWidgetData(
    server: const ServerInstance(
      id: 's',
      name: 'NAS',
      url: 'https://nas',
      authMethod: AuthMethod.apiKey,
      username: 'u',
      secret: 'k',
    ),
    now: DateTime.utc(2026, 10, 26),
    pools: _rows(raw['pools']).map(PoolSummary.fromJson).toList(),
    alerts: _rows(raw['alerts']).map(TrueNasAlert.fromJson).toList(),
    stats: realtime == null ? null : RealtimeStats.fromJson(realtime),
    l10n: l10n,
    jobs: _rows(raw['jobs']).map(TrueNasJob.fromJson).toList(),
    apps: _rows(raw['apps']).map(TrueNasApp.fromJson).toList(),
  );
  // The parts the Swift side makes; the rest is about the server itself.
  return {
    for (final key in ['pools', 'alerts', 'jobs', 'apps', 'system'])
      if (data[key] != null) key: data[key],
  };
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final fixture =
      jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>;
  final cases = [
    for (final c in fixture['cases'] as List<dynamic>)
      c as Map<String, dynamic>,
  ];

  if (Platform.environment['UPDATE_WIDGET_FIXTURE'] == '1') {
    test('rewrite the expected JSON', () {
      fixture['labels'] = homeWidgetLabels(l10n);
      for (final c in cases) {
        c['expected'] = _withoutNulls(
          jsonDecode(
            jsonEncode(_shape(c['raw'] as Map<String, dynamic>, l10n)),
          ),
        );
      }
      File(_fixturePath).writeAsStringSync(
        '${const JsonEncoder.withIndent(' ').convert(fixture)}\n',
      );
    });
    return;
  }

  test('the labels in the fixture are the ones the app sends', () {
    expect(fixture['labels'], homeWidgetLabels(l10n));
  });

  for (final c in cases) {
    test('shapes ${c['name']} as the fixture says', () {
      final shaped = _withoutNulls(
        jsonDecode(jsonEncode(_shape(c['raw'] as Map<String, dynamic>, l10n))),
      );
      expect(shaped, c['expected']);
    });
  }
}
