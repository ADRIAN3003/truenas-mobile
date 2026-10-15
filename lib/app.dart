import 'package:flutter/material.dart';

import 'features/instances/instances_screen.dart';
import 'l10n/generated/app_localizations.dart';

/// Brand-neutral seed colour; dynamic colour replaces it where available.
const _seedColor = Color(0xFF0095D5);

class TrueNasMobileApp extends StatelessWidget {
  const TrueNasMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: _seedColor,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: _seedColor,
        brightness: Brightness.dark,
      ),
      home: const InstancesScreen(),
    );
  }
}
