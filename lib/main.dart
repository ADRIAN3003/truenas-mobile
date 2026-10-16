import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/instances/instance_repository.dart';
import 'core/settings/app_settings.dart';
import 'core/settings/settings_provider.dart';
import 'core/settings/system_language.dart';
import 'features/instances/open_default_server.dart';
import 'features/updates/updates_provider.dart';
import 'shared/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await warmUpGlass();
  // Read the settings first, so the first frame already has the user's theme
  // and language.
  final settings = await (const SettingsRepository(SecureKeyValueStore()))
      .load();
  final systemLanguagePage = await const PlatformSystemLanguage().isSupported();
  runApp(
    ProviderScope(
      overrides: [
        initialSettingsProvider.overrideWithValue(settings),
        systemLanguagePageProvider.overrideWithValue(systemLanguagePage),
        updateAutoCheckProvider.overrideWithValue(true),
        openDefaultServerProvider.overrideWithValue(true),
      ],
      child: wrapForGlass(const TrueNasMobileApp()),
    ),
  );
}
