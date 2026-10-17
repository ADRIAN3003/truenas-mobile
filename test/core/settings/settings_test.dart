import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/models/alert.dart';
import 'package:truenas_mobile/core/settings/app_settings.dart';

import '../../support/memory_store.dart';

void main() {
  test('defaults follow the device and keep every helper on', () {
    const settings = AppSettings();
    expect(settings.theme, ThemeChoice.system);
    expect(settings.language, isNull);
    expect(settings.haptics, isTrue);
    expect(settings.confirmLeave, isTrue);
    expect(settings.shellFontSize, 13);
    expect(settings.shellExtraKeys, isTrue);
    expect(settings.checkForUpdates, isTrue);
    expect(settings.skippedVersion, isNull);
  });

  test('settings round-trip through JSON', () {
    const settings = AppSettings(
      theme: ThemeChoice.dark,
      language: 'hu',
      haptics: false,
      confirmLeave: false,
      shellFontSize: 16,
      shellExtraKeys: false,
      checkForUpdates: false,
      skippedVersion: '0.1.4',
      defaultServerId: 'abc',
      appLock: true,
      alertNotifications: true,
      alertLevel: AlertSeverity.warning,
    );
    final back = AppSettings.fromJson(settings.toJson());
    expect(back.theme, ThemeChoice.dark);
    expect(back.language, 'hu');
    expect(back.haptics, isFalse);
    expect(back.confirmLeave, isFalse);
    expect(back.shellFontSize, 16);
    expect(back.shellExtraKeys, isFalse);
    expect(back.checkForUpdates, isFalse);
    expect(back.skippedVersion, '0.1.4');
    expect(back.defaultServerId, 'abc');
    expect(back.appLock, isTrue);
    expect(back.alertNotifications, isTrue);
    expect(back.alertLevel, AlertSeverity.warning);
  });

  test('unknown or missing values fall back to the defaults', () {
    final settings = AppSettings.fromJson({
      'theme': 'sepia',
      'language': 'xx',
      'shellFontSize': 400,
    });
    expect(settings.theme, ThemeChoice.system);
    expect(settings.language, isNull);
    expect(settings.haptics, isTrue);
    expect(settings.shellFontSize, AppSettings.maxShellFontSize);
    expect(
      AppSettings.fromJson({'shellFontSize': 1}).shellFontSize,
      AppSettings.minShellFontSize,
    );
  });

  test('copyWith can set the language back to the device', () {
    const settings = AppSettings(language: 'hu');
    expect(settings.copyWith(haptics: false).language, 'hu');
    expect(settings.copyWith(language: () => null).language, isNull);
  });

  test('copyWith can skip a version and stop skipping it', () {
    const settings = AppSettings();
    final skipped = settings.copyWith(skippedVersion: () => '0.1.4');
    expect(skipped.skippedVersion, '0.1.4');
    expect(skipped.copyWith(haptics: false).skippedVersion, '0.1.4');
    expect(skipped.copyWith(skippedVersion: () => null).skippedVersion, isNull);
  });

  test('the app lock is off unless it was turned on', () {
    expect(const AppSettings().appLock, isFalse);
    expect(AppSettings.fromJson(const {}).appLock, isFalse);
    final on = const AppSettings().copyWith(appLock: true);
    expect(on.appLock, isTrue);
    expect(on.copyWith(haptics: false).appLock, isTrue);
  });

  test('alert notifications are off, for critical alerts, by default', () {
    const settings = AppSettings();
    expect(settings.alertNotifications, isFalse);
    expect(settings.alertLevel, AlertSeverity.critical);
    final back = AppSettings.fromJson(const {'alertLevel': 'loud'});
    expect(back.alertLevel, AlertSeverity.critical);
  });

  test('copyWith can choose, and clear, the default server', () {
    const settings = AppSettings();
    expect(settings.defaultServerId, isNull);
    final chosen = settings.copyWith(defaultServerId: () => 'abc');
    expect(chosen.defaultServerId, 'abc');
    expect(chosen.copyWith(haptics: false).defaultServerId, 'abc');
    expect(
      chosen.copyWith(defaultServerId: () => null).defaultServerId,
      isNull,
    );
  });

  test('settings saved before updates existed keep the update defaults', () {
    final settings = AppSettings.fromJson({'theme': 'dark'});
    expect(settings.checkForUpdates, isTrue);
    expect(settings.skippedVersion, isNull);
  });

  group('SettingsRepository', () {
    test('nothing saved gives the defaults', () async {
      final settings = await SettingsRepository(MemoryStore()).load();
      expect(settings.theme, ThemeChoice.system);
    });

    test('saves and loads', () async {
      final repository = SettingsRepository(MemoryStore());
      await repository.save(const AppSettings(language: 'en', haptics: false));
      final loaded = await repository.load();
      expect(loaded.language, 'en');
      expect(loaded.haptics, isFalse);
    });

    test('a damaged document gives the defaults instead of failing', () async {
      final store = MemoryStore();
      store.values['settings.v1'] = '{not json';
      final settings = await SettingsRepository(store).load();
      expect(settings.haptics, isTrue);
    });
  });
}
