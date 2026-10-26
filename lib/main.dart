import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/instances/instance_repository.dart';
import 'core/jobs/live_progress.dart';
import 'core/logging/file_log_store.dart';
import 'core/notifications/alert_taps.dart';
import 'core/notifications/background_alerts.dart';
import 'core/notifications/local_alert_notifier.dart';
import 'core/security/biometric_auth.dart';
import 'core/settings/app_settings.dart';
import 'core/settings/settings_provider.dart';
import 'core/settings/system_language.dart';
import 'core/widgets/home_widgets.dart';
import 'features/instances/open_default_server.dart';
import 'features/lock/app_lock_gate.dart';
import 'features/updates/updates_provider.dart';
import 'shared/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logUncaughtErrors();
  await attachLogFile();
  await warmUpGlass();
  // Read the settings first, so the first frame already has the user's theme
  // and language.
  final settings = await (const SettingsRepository(SecureKeyValueStore()))
      .load();
  final systemLanguagePage = await const PlatformSystemLanguage().isSupported();
  // Background alert checks exist on phones only.
  final onPhone = Platform.isAndroid || Platform.isIOS;
  late final ProviderContainer container;
  final notifier = onPhone
      ? LocalAlertNotifier(
          locale: () => settings.language != null
              ? Locale(settings.language!)
              : PlatformDispatcher.instance.locale,
          // A tap on an alert notification opens that server's alerts.
          onTap: (serverId) => container
              .read(pendingAlertServerProvider.notifier)
              .open(serverId),
        )
      : null;
  final launchServer = await notifier?.listenForTaps();
  final alerts = notifier == null
      ? null
      : AlertNotificationService(
          scheduler: const WorkmanagerScheduler(),
          notifier: notifier,
          store: const SecureKeyValueStore(),
          widgets: const PlatformHomeWidgets(),
        );
  if (alerts != null) unawaited(alerts.resume(settings));
  container = ProviderContainer(
    overrides: [
      launchAlertServerProvider.overrideWithValue(launchServer),
      if (alerts != null)
        alertNotificationServiceProvider.overrideWithValue(alerts),
      initialSettingsProvider.overrideWithValue(settings),
      systemLanguagePageProvider.overrideWithValue(systemLanguagePage),
      updateAutoCheckProvider.overrideWithValue(true),
      openDefaultServerProvider.overrideWithValue(true),
      biometricAuthProvider.overrideWithValue(const PlatformBiometricAuth()),
      lockPromptDelayProvider.overrideWithValue(
        const Duration(milliseconds: 400),
      ),
      liveProgressProvider.overrideWithValue(const PlatformLiveProgress()),
      if (alerts != null)
        homeWidgetsBridgeProvider.overrideWithValue(
          const PlatformHomeWidgets(),
        ),
    ],
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: wrapForGlass(const TrueNasMobileApp()),
    ),
  );
}
