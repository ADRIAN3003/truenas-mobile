import 'dart:convert';

import '../instances/instance_repository.dart';
import '../models/alert.dart';

/// The kinds of alert the app has come across, kept on the phone so Settings
/// can list them without a server: the full list TrueNAS gives
/// (`alert.list_categories`) and the kinds of alerts that were really seen.
/// Filled by the alert check.
class AlertKindCatalog {
  const AlertKindCatalog(this._store);

  static const _key = 'alertkinds.v1';

  final KeyValueStore _store;

  /// Every known kind, by name.
  Future<List<AlertKind>> load() async {
    try {
      final raw = await _store.read(_key);
      if (raw == null || raw.isEmpty) return [];
      return [
        for (final e in jsonDecode(raw) as List<dynamic>)
          AlertKind.fromJson(e as Map<String, dynamic>),
      ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    } catch (_) {
      return [];
    }
  }

  /// Adds [kinds]. A name or group that is known replaces one that is not.
  Future<void> record(Iterable<AlertKind> kinds) async {
    final byId = {for (final kind in await load()) kind.id: kind};
    var changed = false;
    for (final kind in kinds) {
      final old = byId[kind.id];
      final merged = AlertKind(
        kind.id,
        title: kind.title ?? old?.title,
        category: kind.category ?? old?.category,
      );
      if (old == null ||
          old.title != merged.title ||
          old.category != merged.category) {
        byId[kind.id] = merged;
        changed = true;
      }
    }
    if (!changed) return;
    await _store.write(
      _key,
      jsonEncode([for (final kind in byId.values) kind.toJson()]),
    );
  }
}
