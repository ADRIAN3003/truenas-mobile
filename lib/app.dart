import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/settings/app_settings.dart';
import 'core/settings/settings_provider.dart';
import 'core/settings/system_language.dart';
import 'features/instances/instances_screen.dart';
import 'features/instances/open_default_server.dart';
import 'features/lock/app_lock_gate.dart';
import 'features/updates/update_prompt.dart';
import 'features/widgets/home_widget_list_sync.dart';
import 'l10n/generated/app_localizations.dart';
import 'shared/theme.dart';

class TrueNasMobileApp extends ConsumerWidget {
  const TrueNasMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    // With a system language page for the app, the language is whatever that
    // says, which the phone already hands the app as its locale.
    final inAppLanguage = ref.watch(systemLanguagePageProvider)
        ? null
        : settings.language;
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: inAppLanguage == null ? null : Locale(inAppLanguage),
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: switch (settings.theme) {
        ThemeChoice.system => ThemeMode.system,
        ThemeChoice.light => ThemeMode.light,
        ThemeChoice.dark => ThemeMode.dark,
      },
      builder: (context, child) => AppLockGate(child: child!),
      home: const UpdateAutoCheck(
        child: HomeWidgetListSync(
          child: OpenDefaultServer(child: InstancesScreen()),
        ),
      ),
    );
  }
}
