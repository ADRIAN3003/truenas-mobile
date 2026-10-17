import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/alert.dart';
import '../../core/notifications/background_alerts.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';

/// The kinds of alert the app has come across, each with a switch: off means
/// no notification for that kind (it still shows in the Alerts list).
final alertKindsProvider = FutureProvider.autoDispose<List<AlertKind>>(
  (ref) => ref.read(alertNotificationServiceProvider).kinds.load(),
);

/// Settings > Notifications > Alert types.
class AlertKindsScreen extends ConsumerStatefulWidget {
  const AlertKindsScreen({super.key});

  @override
  ConsumerState<AlertKindsScreen> createState() => _AlertKindsScreenState();
}

class _AlertKindsScreenState extends ConsumerState<AlertKindsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = ref.watch(settingsProvider.select((s) => s.mutedAlertKinds));
    final known = ref.watch(alertKindsProvider).value ?? const [];
    // Kinds muted from the Alerts list may not be in the catalog yet.
    final kinds = [
      ...known,
      for (final id in muted)
        if (!known.any((kind) => kind.id == id)) AlertKind(id),
    ];
    final needle = _query.trim().toLowerCase();
    final shown = [
      for (final kind in kinds)
        if (needle.isEmpty ||
            kind.label.toLowerCase().contains(needle) ||
            kind.id.toLowerCase().contains(needle))
          kind,
    ];
    final groups = <String, List<AlertKind>>{};
    for (final kind in shown) {
      (groups[kind.category ?? l10n.alertKindsOther] ??= []).add(kind);
    }
    final names = groups.keys.toList()
      ..sort((a, b) {
        // "Other" last.
        if (a == l10n.alertKindsOther) return 1;
        if (b == l10n.alertKindsOther) return -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    return Scaffold(
      appBar: AppBar(title: Text(l10n.alertKindsTitle)),
      body: kinds.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.alertKindsEmpty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppPalette.of(context).muted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(
                  l10n.alertKindsHint,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppPalette.of(context).muted),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: l10n.alertKindsSearch,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                for (final name in names) ...[
                  SectionHeader(name),
                  GroupedCard(
                    indent: 16,
                    children: [
                      for (final kind in groups[name]!)
                        AppSwitchTile(
                          title: Text(kind.label),
                          value: !muted.contains(kind.id),
                          onChanged: (on) => ref
                              .read(settingsProvider.notifier)
                              .update(
                                (s) => s.copyWith(
                                  mutedAlertKinds: {
                                    for (final id in s.mutedAlertKinds)
                                      if (id != kind.id) id,
                                    if (!on) kind.id,
                                  },
                                ),
                              ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}
