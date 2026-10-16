import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/haptics.dart';
import '../instances/instance_repository.dart';
import 'app_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => const SettingsRepository(SecureKeyValueStore()),
);

/// The settings read at start-up, so the first frame already has the right
/// theme and language. `main` overrides it.
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final settings = ref.read(initialSettingsProvider);
    Haptics.enabled = settings.haptics;
    return settings;
  }

  Future<void> update(AppSettings Function(AppSettings current) change) async {
    final next = change(state);
    state = next;
    Haptics.enabled = next.haptics;
    await ref.read(settingsRepositoryProvider).save(next);
  }
}
