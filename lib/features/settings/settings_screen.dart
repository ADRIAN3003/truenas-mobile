import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/instances/default_server.dart';
import '../../core/jobs/live_progress.dart';
import '../../core/instances/instances_provider.dart';
import '../../core/models/alert.dart';
import '../../core/notifications/background_alerts.dart';
import '../../core/security/biometric_auth.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/settings/system_language.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/dialogs.dart';
import '../../shared/haptics.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../updates/update_screen.dart';
import 'alert_kinds_screen.dart';

/// Where the project lives, for the About section.
final _sourceUri = Uri.parse('https://github.com/ADRIAN3003/truenas-mobile');

/// The app's own settings (not a server's): appearance, behaviour, the shell,
/// trusted certificates and About. Stored on the phone only.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          SectionHeader(l10n.settingsAppearance),
          GroupedCard(
            children: [
              _ChoiceRow<ThemeChoice>(
                icon: Icons.contrast_rounded,
                color: AppPalette.tilePurple,
                title: l10n.settingsTheme,
                value: settings.theme,
                options: [
                  (ThemeChoice.system, l10n.settingsSystemDefault),
                  (ThemeChoice.light, l10n.themeLight),
                  (ThemeChoice.dark, l10n.themeDark),
                ],
                onChanged: (theme) =>
                    notifier.update((s) => s.copyWith(theme: theme)),
              ),
              if (ref.watch(systemLanguagePageProvider))
                const _SystemLanguageRow()
              else
                _ChoiceRow<String?>(
                  icon: Icons.language_rounded,
                  color: AppPalette.tileBlue,
                  title: l10n.settingsLanguage,
                  value: settings.language,
                  options: [
                    (null, l10n.settingsSystemDefault),
                    // A language is always named in itself.
                    ('en', 'English'),
                    ('hu', 'Magyar'),
                  ],
                  onChanged: (code) =>
                      notifier.update((s) => s.copyWith(language: () => code)),
                ),
            ],
          ),
          if (ref.watch(instancesProvider).value case final servers?
              when servers.isNotEmpty) ...[
            SectionHeader(l10n.settingsStartup),
            GroupedCard(
              children: [
                _ChoiceRow<String>(
                  icon: Icons.dns_rounded,
                  color: AppPalette.tileBlue,
                  title: l10n.settingsDefaultServer,
                  value:
                      defaultServer(servers, settings.defaultServerId)?.id ??
                      noDefaultServer,
                  options: [
                    (noDefaultServer, l10n.settingsDefaultServerNone),
                    for (final server in servers) (server.id, server.name),
                  ],
                  onChanged: (id) => notifier.update(
                    (s) => s.copyWith(defaultServerId: () => id),
                  ),
                ),
              ],
            ),
          ],
          SectionHeader(l10n.settingsGeneral),
          GroupedCard(
            indent: 16,
            children: [
              AppSwitchTile(
                title: Text(l10n.settingsHaptics),
                subtitle: Text(l10n.settingsHapticsHint),
                value: settings.haptics,
                onChanged: (on) =>
                    notifier.update((s) => s.copyWith(haptics: on)),
              ),
              AppSwitchTile(
                title: Text(l10n.settingsConfirmLeave),
                subtitle: Text(l10n.settingsConfirmLeaveHint),
                value: settings.confirmLeave,
                onChanged: (on) =>
                    notifier.update((s) => s.copyWith(confirmLeave: on)),
              ),
            ],
          ),
          SectionHeader(l10n.settingsShell),
          GroupedCard(
            indent: 16,
            children: [
              ListTile(
                title: Text(l10n.settingsShellFontSize),
                subtitle: AppSlider(
                  min: AppSettings.minShellFontSize,
                  max: AppSettings.maxShellFontSize,
                  divisions:
                      (AppSettings.maxShellFontSize -
                              AppSettings.minShellFontSize)
                          .round(),
                  value: settings.shellFontSize,
                  label: settings.shellFontSize.round().toString(),
                  onChanged: (size) =>
                      notifier.update((s) => s.copyWith(shellFontSize: size)),
                  onChangeEnd: (_) => Haptics.selection(),
                ),
                trailing: Text(
                  settings.shellFontSize.round().toString(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              AppSwitchTile(
                title: Text(l10n.settingsShellKeys),
                subtitle: Text(l10n.settingsShellKeysHint),
                value: settings.shellExtraKeys,
                onChanged: (on) =>
                    notifier.update((s) => s.copyWith(shellExtraKeys: on)),
              ),
            ],
          ),
          SectionHeader(l10n.settingsNotifications),
          _NotificationsCard(
            alertsSupported: ref
                .watch(alertNotificationServiceProvider)
                .isSupported,
          ),
          SectionHeader(l10n.settingsSecurity),
          // Shown while the phone can ask, and also while the lock is on so
          // it can always be turned off.
          if (ref.watch(biometricAvailableProvider).value == true ||
              settings.appLock) ...[
            const _AppLockTile(),
            const SizedBox(height: 12),
          ],
          GroupedCard(
            children: [
              NavRow(
                icon: Icons.verified_user_rounded,
                color: AppPalette.tileGreen,
                title: l10n.settingsCertificates,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const TrustedCertificatesScreen(),
                  ),
                ),
              ),
            ],
          ),
          SectionHeader(l10n.settingsUpdates),
          GroupedCard(
            indent: 16,
            children: [
              AppSwitchTile(
                title: Text(l10n.settingsCheckUpdates),
                subtitle: Text(l10n.settingsCheckUpdatesHint),
                value: settings.checkForUpdates,
                onChanged: (on) =>
                    notifier.update((s) => s.copyWith(checkForUpdates: on)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GroupedCard(
            children: [
              NavRow(
                icon: Icons.system_update_rounded,
                color: AppPalette.tileBlue,
                title: l10n.settingsCheckNow,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const UpdateScreen()),
                ),
              ),
              NavRow(
                icon: Icons.history_rounded,
                color: AppPalette.tileSlate,
                title: l10n.settingsReleaseNotes,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ReleaseNotesScreen(),
                  ),
                ),
              ),
            ],
          ),
          SectionHeader(l10n.settingsAbout),
          GroupedCard(
            children: [
              const _VersionRow(),
              NavRow(
                icon: Icons.description_rounded,
                color: AppPalette.tileSlate,
                title: l10n.settingsLicences,
                onTap: () => showLicensePage(context: context),
              ),
              NavRow(
                icon: Icons.code_rounded,
                color: AppPalette.tileTeal,
                title: l10n.settingsSource,
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () =>
                    launchUrl(_sourceUri, mode: LaunchMode.externalApplication),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the app may notify about: new alerts (the switch, the lowest level
/// and the kinds to leave out) and the live progress of running jobs. Turning
/// alerts on asks the phone for permission to show notifications; if that is
/// refused the switch stays off.
class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard({required this.alertsSupported});

  /// Whether this phone can check for alerts in the background.
  final bool alertsSupported;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return GroupedCard(
      indent: 16,
      children: [
        if (alertsSupported)
          AppSwitchTile(
            title: Text(l10n.settingsAlertNotifications),
            subtitle: Text(
              Platform.isIOS
                  ? l10n.settingsAlertNotificationsHintIos
                  : l10n.settingsAlertNotificationsHintAndroid,
            ),
            value: settings.alertNotifications,
            onChanged: (on) async {
              final service = ref.read(alertNotificationServiceProvider);
              final servers = ref.read(instancesProvider).value ?? const [];
              final messenger = ScaffoldMessenger.of(context);
              final denied = l10n.settingsAlertPermissionDenied;
              final failed = l10n.settingsAlertScheduleFailed;
              if (on) {
                final result = await service.turnOn(
                  servers,
                  level: settings.alertLevel,
                );
                if (result != AlertTurnOn.on) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        result == AlertTurnOn.denied ? denied : failed,
                      ),
                    ),
                  );
                  return;
                }
              } else {
                await service.turnOff(keepForWidgets: settings.homeWidgets);
              }
              await notifier.update((s) => s.copyWith(alertNotifications: on));
            },
          ),
        if (alertsSupported && settings.alertNotifications)
          _ChoiceRow<AlertSeverity>(
            icon: Icons.notifications_active_rounded,
            color: AppPalette.tileOrange,
            title: l10n.settingsAlertLevel,
            value: settings.alertLevel,
            options: [
              (AlertSeverity.critical, l10n.settingsAlertLevelCritical),
              (AlertSeverity.warning, l10n.settingsAlertLevelWarning),
            ],
            onChanged: (level) =>
                notifier.update((s) => s.copyWith(alertLevel: level)),
          ),
        if (alertsSupported && settings.alertNotifications)
          NavRow(
            icon: Icons.tune_rounded,
            color: AppPalette.tileSlate,
            title: l10n.settingsAlertKinds,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.settingsAlertKindsMuted(settings.mutedAlertKinds.length),
                  style: TextStyle(color: AppPalette.of(context).muted),
                ),
                const SizedBox(width: 4),
                const Chevron(),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const AlertKindsScreen()),
            ),
          ),
        AppSwitchTile(
          title: Text(l10n.settingsLiveJobs),
          subtitle: Text(switch (ref.watch(liveSupportProvider).value) {
            LiveSupport.noExtension => l10n.settingsLiveJobsNoExtension,
            LiveSupport.disabled => l10n.settingsLiveJobsDisabled,
            _ => l10n.settingsLiveJobsHint,
          }),
          value: settings.liveJobs,
          onChanged: (on) => notifier.update((s) => s.copyWith(liveJobs: on)),
        ),
        if (alertsSupported)
          AppSwitchTile(
            title: Text(l10n.settingsHomeWidgets),
            subtitle: Text(l10n.settingsHomeWidgetsHint),
            value: settings.homeWidgets,
            onChanged: (on) async {
              final service = ref.read(alertNotificationServiceProvider);
              final next = settings.copyWith(homeWidgets: on);
              await notifier.update((s) => s.copyWith(homeWidgets: on));
              if (on) {
                await service.resume(next);
              } else if (!next.alertNotifications) {
                await service.turnOff();
              }
            },
          ),
      ],
    );
  }
}

/// The app lock switch. Changing it asks the phone for Face ID, a fingerprint
/// or the passcode first, so nobody who picks up an unlocked phone can switch
/// the lock off, and a lock that cannot be passed is never turned on.
class _AppLockTile extends ConsumerWidget {
  const _AppLockTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final on = ref.watch(settingsProvider.select((s) => s.appLock));
    final hint = switch (ref.watch(biometricKindProvider).value) {
      BiometricKind.face => l10n.settingsAppLockHintFace,
      BiometricKind.fingerprint => l10n.settingsAppLockHintFingerprint,
      _ => l10n.settingsAppLockHintOther,
    };
    return GroupedCard(
      indent: 16,
      children: [
        AppSwitchTile(
          title: Text(l10n.settingsAppLock),
          subtitle: Text(hint),
          value: on,
          onChanged: (next) async {
            final auth = ref.read(biometricAuthProvider);
            final notifier = ref.read(settingsProvider.notifier);
            final reason = l10n.appLockChangeReason;
            // With nothing left to ask (the biometrics were removed from the
            // phone), turning the lock off must still be possible.
            final canAsk = await auth.isAvailable();
            if (canAsk && !await auth.authenticate(reason)) return;
            if (!canAsk && next) return;
            await notifier.update((s) => s.copyWith(appLock: next));
          },
        ),
      ],
    );
  }
}

/// The Language row where the phone has a language page for the app (iOS, and
/// Android 13 and newer): it shows the language in use and opens that page,
/// because the language is changed there and not inside the app.
class _SystemLanguageRow extends ConsumerWidget {
  const _SystemLanguageRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final muted = AppPalette.of(context).muted;
    // A language is always named in itself.
    final current = switch (Localizations.localeOf(context).languageCode) {
      'hu' => 'Magyar',
      _ => 'English',
    };
    return ListTile(
      leading: const IconTile(Icons.language_rounded, AppPalette.tileBlue),
      title: Text(l10n.settingsLanguage),
      subtitle: Text(l10n.settingsLanguageSystemHint),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(current, style: TextStyle(color: muted)),
          const SizedBox(width: 8),
          Icon(Icons.open_in_new_rounded, size: 18, color: muted),
        ],
      ),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await ref.read(systemLanguageProvider).open();
        } catch (_) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.settingsLanguageOpenFailed)),
          );
        }
      },
    );
  }
}

/// A row that shows the current choice and lets the user pick another from a
/// sheet.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final T value;

  /// Each choice and its label.
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = AppPalette.of(context).muted;
    final current = options.firstWhere((o) => o.$1 == value).$2;
    return ListTile(
      leading: IconTile(icon, color),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(current, style: TextStyle(color: muted)),
          const SizedBox(width: 4),
          const Chevron(),
        ],
      ),
      onTap: () async {
        // A record, so choosing the "null" option is told apart from
        // dismissing the sheet.
        final picked = await showAppChoice<T>(
          context: context,
          title: title,
          choices: [
            for (final (choice, label) in options)
              appChoice(choice, label, selected: choice == value),
          ],
        );
        if (picked != null && picked.$1 != value) {
          Haptics.selection();
          onChanged(picked.$1);
        }
      },
    );
  }
}

/// The app's version and build number.
class _VersionRow extends StatelessWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context) => NavRow(
    icon: Icons.info_rounded,
    color: AppPalette.tileBlue,
    title: AppLocalizations.of(context).settingsVersion,
    trailing: FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        return Text(
          info == null ? '' : '${info.version} (${info.buildNumber})',
          style: TextStyle(color: AppPalette.of(context).muted),
        );
      },
    ),
  );
}

/// The certificates the user chose to trust for self-signed servers, with a
/// way to take the trust back.
class TrustedCertificatesScreen extends ConsumerWidget {
  const TrustedCertificatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pinned = [
      for (final i in ref.watch(instancesProvider).value ?? const [])
        if (i.pinnedFingerprint != null) i,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsCertificates)),
      body: pinned.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.settingsCertificatesEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppPalette.of(context).muted,
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                GroupedCard(
                  indent: 16,
                  children: [
                    for (final instance in pinned)
                      ListTile(
                        title: Text(instance.name),
                        subtitle: Text(
                          instance.pinnedFingerprint!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            final notifier = ref.read(
                              instancesProvider.notifier,
                            );
                            final confirmed = await confirmAction(
                              context,
                              title: l10n.settingsCertificateForgetTitle(
                                instance.name,
                              ),
                              body: l10n.settingsCertificateForgetBody,
                              confirmLabel: l10n.settingsCertificateForget,
                              cancelLabel: l10n.cancel,
                              destructive: true,
                            );
                            if (confirmed) {
                              await notifier.upsert(
                                instance.copyWith(
                                  pinnedFingerprint: () => null,
                                ),
                              );
                            }
                          },
                          child: Text(l10n.settingsCertificateForget),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
