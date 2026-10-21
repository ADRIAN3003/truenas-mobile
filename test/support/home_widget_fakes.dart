import 'dart:convert';

import 'package:truenas_mobile/core/widgets/home_widgets.dart';

/// The widgets' shared storage, without a phone.
class FakeHomeWidgets implements HomeWidgetsBridge {
  FakeHomeWidgets({this.installed = true});

  /// Whether the user has a widget on a home screen.
  bool installed;

  String? document;
  int reloads = 0;

  /// The saved document as JSON, or an empty map.
  Map<String, dynamic> get json =>
      document == null ? {} : jsonDecode(document!) as Map<String, dynamic>;

  /// The saved servers, by id.
  Map<String, Map<String, dynamic>> get servers => {
    for (final s in (json['servers'] as List? ?? const []))
      (s as Map<String, dynamic>)['id'] as String: s,
  };

  @override
  Future<String?> read() async => document;

  @override
  Future<void> write(String json) async => document = json;

  @override
  Future<void> reload() async => reloads++;

  @override
  Future<bool> hasWidgets() async => installed;
}
