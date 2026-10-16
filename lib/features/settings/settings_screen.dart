import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/instances/instances_provider.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/dialogs.dart';
import '../../shared/haptics.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';

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
                subtitle: Slider.adaptive(
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
          SectionHeader(l10n.settingsSecurity),
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
        final picked = await showAppSheet<(T,)>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (choice, label) in options)
                  ListTile(
                    title: Text(label),
                    trailing: choice == value
                        ? Icon(
                            Icons.check_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.pop(context, (choice,)),
                  ),
              ],
            ),
          ),
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
