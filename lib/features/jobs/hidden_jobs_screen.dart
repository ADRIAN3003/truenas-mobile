import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';

/// The job types the Jobs list leaves out, each with a button to show it
/// again. Opened from the row at the bottom of the Jobs list.
class HiddenJobsScreen extends ConsumerWidget {
  const HiddenJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hidden =
        ref.watch(settingsProvider.select((s) => s.hiddenJobMethods)).toList()
          ..sort();
    final muted = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: AppPalette.of(context).muted);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.hiddenJobsTitle)),
      body: hidden.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.hiddenJobsEmpty,
                  textAlign: TextAlign.center,
                  style: muted,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(l10n.hiddenJobsHint, style: muted),
                const SizedBox(height: 12),
                GroupedCard(
                  indent: 16,
                  children: [
                    for (final method in hidden)
                      ListTile(
                        title: Text(method),
                        trailing: TextButton(
                          onPressed: () => ref
                              .read(settingsProvider.notifier)
                              .update(
                                (s) => s.copyWith(
                                  hiddenJobMethods: {
                                    for (final m in s.hiddenJobMethods)
                                      if (m != method) m,
                                  },
                                ),
                              ),
                          child: Text(l10n.hiddenJobsShow),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => ref
                        .read(settingsProvider.notifier)
                        .update((s) => s.copyWith(hiddenJobMethods: const {})),
                    child: Text(l10n.hiddenJobsShowAll),
                  ),
                ),
              ],
            ),
    );
  }
}
