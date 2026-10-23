import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  /// Hands the sign-in details of the saved servers to the iOS widgets, which
  /// fetch their own data (see [HomeWidgetPublisher.publish]). Null removes
  /// them. Never throws.
  Future<void> writeCredentials(String? json);
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

  @override
  Future<void> writeCredentials(String? json) async {}
}

/// The iOS App Group the app and the widget extension share.
const homeWidgetAppGroup = 'group.hu.adrian.truenasmobile';

/// The native side that keeps the servers' sign-in details in a Keychain
/// group the widget extension can read (`WidgetCredentialsPlugin.swift`).
const _credentialsChannel = MethodChannel(
  'hu.adrian.truenasmobile/widget_credentials',
);

/// The storage key of the document.
const _documentKey = 'snapshot.v1';

/// The kinds of the iOS widgets, as `JobActivityWidget` declares them.
const _iosKinds = [
  'TrueNASPools',
  'TrueNASSystem',
  'TrueNASAlerts',
  'TrueNASActivity',
];

/// The Android widget providers.
const _androidProviders = [
  'hu.adrian.truenasmobile.PoolsWidgetProvider',
  'hu.adrian.truenasmobile.SystemWidgetProvider',
  'hu.adrian.truenasmobile.AlertsWidgetProvider',
  'hu.adrian.truenasmobile.ActivityWidgetProvider',
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

  /// What was last handed over, so the Keychain is not written every minute.
  static String? _lastCredentials;

  @override
  Future<void> writeCredentials(String? json) async {
    // Only iOS widgets fetch by themselves; Android's are kept current by the
    // background check.
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (json == _lastCredentials) return;
    try {
      if (json == null) {
        await _credentialsChannel.invokeMethod<void>('clear');
      } else {
        await _credentialsChannel.invokeMethod<void>('save', json);
      }
      _lastCredentials = json;
    } catch (_) {
      // No such native side (the background engine) or no Keychain group (a
      // sideloaded install): the widgets then rely on what the app saves.
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
      await bridge.writeCredentials(_credentials(servers));
      await bridge.reload();
    } catch (_) {
      // The widgets keep showing what they had.
    }
  }

  /// Forgets everything, as when the last server is removed or the widgets
  /// are switched off.
  Future<void> clear() async {
    try {
      await bridge.write(
        jsonEncode({'v': 1, 'labels': const {}, 'servers': const []}),
      );
      await bridge.writeCredentials(null);
      await bridge.reload();
    } catch (_) {}
  }

  /// Just what a widget needs to sign in by itself. The iOS widget extension
  /// is its own process, and the phone may not wake the app to refresh it, so
  /// it asks the server directly; the details live in a Keychain group shared
  /// with it, never in the App Group's plain preferences.
  String? _credentials(List<ServerInstance> servers) => servers.isEmpty
      ? null
      : jsonEncode({
          'v': 1,
          'servers': [
            for (final server in servers)
              {
                'id': server.id,
                'name': server.name,
                'url': server.url,
                'authMethod': server.authMethod.name,
                'username': server.username,
                'secret': server.secret,
                'pinnedFingerprint': server.pinnedFingerprint,
                'apiVersion': server.lastApiVersion,
              },
          ],
        });

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
