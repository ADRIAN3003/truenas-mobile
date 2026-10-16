import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/instances/instance_repository.dart';
import 'core/settings/app_settings.dart';
import 'core/settings/settings_provider.dart';
import 'shared/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await warmUpGlass();
  // Read the settings first, so the first frame already has the user's theme
  // and language.
  final settings = await (const SettingsRepository(SecureKeyValueStore()))
      .load();
  runApp(
    ProviderScope(
      overrides: [initialSettingsProvider.overrideWithValue(settings)],
      child: wrapForGlass(const TrueNasMobileApp()),
    ),
  );
}
