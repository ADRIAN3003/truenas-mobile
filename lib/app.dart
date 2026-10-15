import 'package:flutter/material.dart';

import 'features/instances/instances_screen.dart';
import 'l10n/generated/app_localizations.dart';
import 'shared/theme.dart';

class TrueNasMobileApp extends StatelessWidget {
  const TrueNasMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: const InstancesScreen(),
    );
  }
}
