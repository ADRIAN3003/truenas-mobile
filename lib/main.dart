import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/instances/instance_repository.dart';
import 'core/jobs/live_progress.dart';
import 'core/notifications/background_alerts.dart';
import 'core/notifications/local_alert_notifier.dart';
import 'core/security/biometric_auth.dart';
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
  // Background alert checks exist on phones only.
  final alerts = Platform.isAndroid || Platform.isIOS
      ? AlertNotificationService(
          scheduler: const WorkmanagerScheduler(),
          notifier: LocalAlertNotifier(
            locale: () => settings.language != null
                ? Locale(settings.language!)
                : PlatformDispatcher.instance.locale,
          ),
          store: const SecureKeyValueStore(),
        )
      : null;
  if (alerts != null) unawaited(alerts.resume(settings));
  runApp(
    ProviderScope(
      overrides: [
        if (alerts != null)
          alertNotificationServiceProvider.overrideWithValue(alerts),
        initialSettingsProvider.overrideWithValue(settings),
        systemLanguagePageProvider.overrideWithValue(systemLanguagePage),
        updateAutoCheckProvider.overrideWithValue(true),
        openDefaultServerProvider.overrideWithValue(true),
        biometricAuthProvider.overrideWithValue(const PlatformBiometricAuth()),
        liveProgressProvider.overrideWithValue(const PlatformLiveProgress()),
      ],
      child: wrapForGlass(const TrueNasMobileApp()),
    ),
  );
}
