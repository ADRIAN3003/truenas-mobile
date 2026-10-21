import 'dart:convert';

import '../instances/instance_repository.dart';
import '../models/alert.dart';

/// How the app picks light or dark.
enum ThemeChoice { system, light, dark }

/// What the user can change in the app itself. Stored on the phone only.
class AppSettings {
  const AppSettings({
    this.theme = ThemeChoice.system,
    this.language,
    this.haptics = true,
    this.confirmLeave = true,
    this.shellFontSize = defaultShellFontSize,
    this.shellExtraKeys = true,
    this.checkForUpdates = true,
    this.skippedVersion,
    this.defaultServerId,
    this.appLock = false,
    this.liveJobs = true,
    this.alertNotifications = false,
    this.alertLevel = AlertSeverity.critical,
    this.mutedAlertKinds = const {},
    this.homeWidgets = true,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    theme: ThemeChoice.values.asNameMap()[json['theme']] ?? ThemeChoice.system,
    language: supportedLanguages.contains(json['language'])
        ? json['language'] as String
        : null,
    haptics: json['haptics'] as bool? ?? true,
    confirmLeave: json['confirmLeave'] as bool? ?? true,
    shellFontSize:
        ((json['shellFontSize'] as num?)?.toDouble() ?? defaultShellFontSize)
            .clamp(minShellFontSize, maxShellFontSize),
    shellExtraKeys: json['shellExtraKeys'] as bool? ?? true,
    checkForUpdates: json['checkForUpdates'] as bool? ?? true,
    skippedVersion: json['skippedVersion'] as String?,
    defaultServerId: json['defaultServerId'] as String?,
    appLock: json['appLock'] as bool? ?? false,
    liveJobs: json['liveJobs'] as bool? ?? true,
    alertNotifications: json['alertNotifications'] as bool? ?? false,
    alertLevel:
        AlertSeverity.values.asNameMap()[json['alertLevel']] ??
        AlertSeverity.critical,
    mutedAlertKinds: {
      for (final id in (json['mutedAlertKinds'] as List?) ?? const [])
        if (id is String && id.isNotEmpty) id,
    },
    homeWidgets: json['homeWidgets'] as bool? ?? true,
  );

  /// Language codes the app is translated into.
  static const supportedLanguages = ['en', 'hu'];

  static const defaultShellFontSize = 13.0;
  static const minShellFontSize = 10.0;
  static const maxShellFontSize = 20.0;

  final ThemeChoice theme;

  /// A code from [supportedLanguages], or null to follow the device.
  final String? language;

  /// Taps and ticks on refresh, switches, tabs and confirmations.
  final bool haptics;

  /// Ask before leaving an open server or shell.
  final bool confirmLeave;

  final double shellFontSize;

  /// Esc, Tab, Ctrl+C and the arrows under the terminal. Copy and paste
  /// stay either way.
  final bool shellExtraKeys;

  /// Look for a newer release on GitHub when the app opens.
  final bool checkForUpdates;

  /// The release (e.g. `0.1.4`) the user chose to skip: it is not offered
  /// again when the app opens, but a newer one is.
  final String? skippedVersion;

  /// The id of the server the app opens by itself at start, `''` for none,
  /// or null when the user has not chosen (then a single saved server is the
  /// default). See `defaultServer` in `default_server.dart`.
  final String? defaultServerId;

  /// Ask for Face ID, a fingerprint or the device passcode when the app opens
  /// and each time it comes back from the background.
  final bool appLock;

  /// Show running scrubs, replications and updates on the lock screen (a Live
  /// Activity on iOS, a progress notification on Android).
  final bool liveJobs;

  /// Check the saved servers in the background and show a notification for
  /// each new alert at or above [alertLevel].
  final bool alertNotifications;

  /// The lowest [AlertSeverity] that is worth a notification. `info` is not
  /// offered: it would only ever be noise.
  final AlertSeverity alertLevel;

  /// The kinds of alert (`AlertKind.id`) the user does not want a
  /// notification for. They still show in the Alerts list.
  final Set<String> mutedAlertKinds;

  /// Keep the home screen widgets up to date in the background (about every
  /// 15 minutes, when the phone allows it). They also update whenever a
  /// server is open in the app. Does nothing until a widget is added.
  final bool homeWidgets;

  AppSettings copyWith({
    ThemeChoice? theme,
    String? Function()? language,
    bool? haptics,
    bool? confirmLeave,
    double? shellFontSize,
    bool? shellExtraKeys,
    bool? checkForUpdates,
    String? Function()? skippedVersion,
    String? Function()? defaultServerId,
    bool? appLock,
    bool? liveJobs,
    bool? alertNotifications,
    AlertSeverity? alertLevel,
    Set<String>? mutedAlertKinds,
    bool? homeWidgets,
  }) => AppSettings(
    theme: theme ?? this.theme,
    language: language != null ? language() : this.language,
    haptics: haptics ?? this.haptics,
    confirmLeave: confirmLeave ?? this.confirmLeave,
    shellFontSize: shellFontSize ?? this.shellFontSize,
    shellExtraKeys: shellExtraKeys ?? this.shellExtraKeys,
    checkForUpdates: checkForUpdates ?? this.checkForUpdates,
    skippedVersion: skippedVersion != null
        ? skippedVersion()
        : this.skippedVersion,
    defaultServerId: defaultServerId != null
        ? defaultServerId()
        : this.defaultServerId,
    appLock: appLock ?? this.appLock,
    liveJobs: liveJobs ?? this.liveJobs,
    alertNotifications: alertNotifications ?? this.alertNotifications,
    alertLevel: alertLevel ?? this.alertLevel,
    mutedAlertKinds: mutedAlertKinds ?? this.mutedAlertKinds,
    homeWidgets: homeWidgets ?? this.homeWidgets,
  );

  Map<String, dynamic> toJson() => {
    'theme': theme.name,
    'language': language,
    'haptics': haptics,
    'confirmLeave': confirmLeave,
    'shellFontSize': shellFontSize,
    'shellExtraKeys': shellExtraKeys,
    'checkForUpdates': checkForUpdates,
    'skippedVersion': skippedVersion,
    'defaultServerId': defaultServerId,
    'appLock': appLock,
    'liveJobs': liveJobs,
    'alertNotifications': alertNotifications,
    'alertLevel': alertLevel.name,
    'mutedAlertKinds': mutedAlertKinds.toList()..sort(),
    'homeWidgets': homeWidgets,
  };
}

/// Loads and saves [AppSettings] as one JSON document.
class SettingsRepository {
  const SettingsRepository(this._store);

  static const _key = 'settings.v1';

  final KeyValueStore _store;

  /// The saved settings, or the defaults when there are none or they cannot
  /// be read.
  Future<AppSettings> load() async {
    try {
      final raw = await _store.read(_key);
      if (raw == null || raw.isEmpty) return const AppSettings();
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) =>
      _store.write(_key, jsonEncode(settings.toJson()));
}
