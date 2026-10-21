import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../instances/default_server.dart';
import '../instances/server_instance.dart';

/// Where the home screen widgets read from. The real one is
/// [PlatformHomeWidgets]; tests use a fake.
///
/// What is saved is one JSON document (see [HomeWidgetPublisher]). The phone
/// keeps it where the widgets can reach it: the App Group on iOS, the widget
/// preferences on Android.
abstract interface class HomeWidgetsBridge {
  /// The saved document, or null when there is none.
  Future<String?> read();

  Future<void> write(String json);

  /// Tells the widgets on the home screen to draw again.
  Future<void> reload();

  /// Whether the user has put any of the widgets on a home screen.
  Future<bool> hasWidgets();
}

/// For platforms without widgets, and as the default in tests.
class NoHomeWidgets implements HomeWidgetsBridge {
  const NoHomeWidgets();

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String json) async {}

  @override
  Future<void> reload() async {}

  @override
  Future<bool> hasWidgets() async => false;
}

/// The iOS App Group the app and the widget extension share.
const homeWidgetAppGroup = 'group.hu.adrian.truenasmobile';

/// The storage key of the document.
const _documentKey = 'snapshot.v1';

/// The kinds of the iOS widgets, as `JobActivityWidget` declares them.
const _iosKinds = ['TrueNASPools', 'TrueNASSystem', 'TrueNASAlerts'];

/// The Android widget providers.
const _androidProviders = [
  'hu.adrian.truenasmobile.PoolsWidgetProvider',
  'hu.adrian.truenasmobile.SystemWidgetProvider',
  'hu.adrian.truenasmobile.AlertsWidgetProvider',
];

/// Saves the widgets' data through the `home_widget` plugin, which works in
/// the background check's headless engine too.
class PlatformHomeWidgets implements HomeWidgetsBridge {
  const PlatformHomeWidgets();

  bool get _supported =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  Future<void> _ready() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await HomeWidget.setAppGroupId(homeWidgetAppGroup);
    }
  }

  @override
  Future<String?> read() async {
    if (!_supported) return null;
    await _ready();
    return HomeWidget.getWidgetData<String>(_documentKey);
  }

  @override
  Future<void> write(String json) async {
    if (!_supported) return;
    await _ready();
    await HomeWidget.saveWidgetData<String>(_documentKey, json);
  }

  @override
  Future<void> reload() async {
    if (!_supported) return;
    await _ready();
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    for (final name in ios ? _iosKinds : _androidProviders) {
      await HomeWidget.updateWidget(
        iOSName: ios ? name : null,
        qualifiedAndroidName: ios ? null : name,
      );
    }
  }

  @override
  Future<bool> hasWidgets() async {
    if (!_supported) return false;
    try {
      await _ready();
      return (await HomeWidget.getInstalledWidgets()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

/// What the widgets know. Never throws: a widget that cannot be updated is
/// no reason to fail whatever called this.
class HomeWidgetPublisher {
  HomeWidgetPublisher(this.bridge);

  final HomeWidgetsBridge bridge;

  /// Saves [fresh] (the data of servers just looked at, by server id) and
  /// marks [unreachable] servers, keeping what was known about the rest.
  /// Servers that are no longer saved are dropped, and [servers] sets the
  /// order. Then the widgets are told to draw again.
  ///
  /// [labels] is saved with it, in the user's language of the moment.
  Future<void> publish({
    required List<ServerInstance> servers,
    required Map<String, Map<String, dynamic>> fresh,
    required Map<String, String> labels,
    Set<String> unreachable = const {},
    String? chosenDefault,
  }) async {
    try {
      final known = _parse(await bridge.read());
      final entries = <Map<String, dynamic>>[
        for (final server in servers)
          {
            ...?known[server.id],
            ...?fresh[server.id],
            'id': server.id,
            'name': server.name,
            if (unreachable.contains(server.id) &&
                !fresh.containsKey(server.id))
              'unreachable': true,
          },
      ];
      await bridge.write(
        jsonEncode({
          'v': 1,
          'labels': labels,
          'defaultId': defaultServer(servers, chosenDefault)?.id,
          'servers': entries,
        }),
      );
      await bridge.reload();
    } catch (_) {
      // The widgets keep showing what they had.
    }
  }

  /// Forgets everything, as when the last server is removed.
  Future<void> clear() async {
    try {
      await bridge.write(
        jsonEncode({'v': 1, 'labels': const {}, 'servers': const []}),
      );
      await bridge.reload();
    } catch (_) {}
  }

  Map<String, Map<String, dynamic>> _parse(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final servers = (jsonDecode(raw) as Map<String, dynamic>)['servers'];
      return {
        for (final entry in servers as List<dynamic>)
          if (entry is Map<String, dynamic> && entry['id'] is String)
            entry['id'] as String: entry,
      };
    } catch (_) {
      return {};
    }
  }
}

final homeWidgetsBridgeProvider = Provider<HomeWidgetsBridge>(
  (ref) => const NoHomeWidgets(),
);

final homeWidgetPublisherProvider = Provider<HomeWidgetPublisher>(
  (ref) => HomeWidgetPublisher(ref.watch(homeWidgetsBridgeProvider)),
);
