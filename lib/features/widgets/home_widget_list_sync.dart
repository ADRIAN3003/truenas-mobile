import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/instances/instances_provider.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/widgets/home_widget_data.dart';
import '../../core/widgets/home_widget_sync.dart';
import '../../core/widgets/home_widgets.dart';

/// Tells the home screen widgets which servers are saved, from the moment the
/// app starts and whenever the list changes. A widget's server picker (iOS)
/// and chooser (Android) list those, so they must not wait for a server to be
/// opened. Servers it has no data for yet are listed without any, and the
/// widget asks the user to open the app. Wraps the first screen.
class HomeWidgetListSync extends ConsumerStatefulWidget {
  const HomeWidgetListSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HomeWidgetListSync> createState() => _HomeWidgetListSyncState();
}

class _HomeWidgetListSyncState extends ConsumerState<HomeWidgetListSync> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _publish());
  }

  Future<void> _publish() async {
    if (!mounted || !ref.read(settingsProvider).homeWidgets) return;
    final servers = ref.read(instancesProvider).value;
    // A list that could not be read is not "no servers".
    if (servers == null) return;
    final locale = Localizations.localeOf(context);
    await ref
        .read(homeWidgetPublisherProvider)
        .publish(
          servers: servers,
          fresh: const {},
          labels: homeWidgetLabels(localizationsFor(locale)),
          chosenDefault: ref.read(settingsProvider).defaultServerId,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(instancesProvider, (_, _) => unawaited(_publish()));
    ref.listen(
      settingsProvider.select((s) => (s.homeWidgets, s.defaultServerId)),
      (_, _) => unawaited(_publish()),
    );
    return widget.child;
  }
}
