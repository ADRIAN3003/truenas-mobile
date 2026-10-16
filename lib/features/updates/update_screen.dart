import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/settings/settings_provider.dart';
import '../../core/updates/release.dart';
import '../../core/updates/update_checker.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import 'updates_provider.dart';

/// Looks for a newer release on GitHub, shows what is new and installs it:
/// from inside the app on Android, from the release page elsewhere.
class UpdateScreen extends ConsumerStatefulWidget {
  const UpdateScreen({super.key});

  @override
  ConsumerState<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends ConsumerState<UpdateScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the screen is asking for a fresh look.
    Future.microtask(() => ref.read(updateStatusProvider.notifier).check());
  }

  Future<void> _check() => ref.read(updateStatusProvider.notifier).check();

  Future<void> _install(ReleaseInfo release) async {
    final failure = await ref.read(apkProvider.notifier).install(release);
    if (failure == ApkFailure.permission && mounted) {
      final l10n = AppLocalizations.of(context);
      final open = await confirmAction(
        context,
        title: l10n.appUpdatePermissionTitle,
        body: l10n.appUpdatePermissionBody,
        confirmLabel: l10n.appUpdateOpenSettings,
        cancelLabel: l10n.cancel,
      );
      if (open) await ref.read(apkInstallerProvider).openInstallSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(updateStatusProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appUpdateTitle)),
      body: _UpdateBody(
        status: status,
        onRetry: _check,
        builder: (data) => _content(context, data),
      ),
    );
  }

  Widget _content(BuildContext context, UpdateStatus data) {
    final l10n = AppLocalizations.of(context);
    final latest = data.latest;
    final shown = data.updateAvailable ? data.newer : [?latest];
    return AppRefreshIndicator(
      onRefresh: _check,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _StatusCard(data: data, onInstall: _install),
          if (shown.isNotEmpty) SectionHeader(l10n.appUpdateWhatsNew),
          for (final (i, release) in shown.indexed)
            _NotesCard(release, expanded: i == 0),
          if (data.releases.isNotEmpty) ...[
            const SizedBox(height: 16),
            GroupedCard(
              children: [
                NavRow(
                  icon: Icons.history_rounded,
                  color: AppPalette.tileSlate,
                  title: l10n.appUpdateAllNotes,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ReleaseNotesScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Every published release with its notes, newest first.
class ReleaseNotesScreen extends ConsumerStatefulWidget {
  const ReleaseNotesScreen({super.key});

  @override
  ConsumerState<ReleaseNotesScreen> createState() => _ReleaseNotesScreenState();
}

class _ReleaseNotesScreenState extends ConsumerState<ReleaseNotesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (ref.read(updateStatusProvider).value == null) {
        ref.read(updateStatusProvider.notifier).check();
      }
    });
  }

  Future<void> _check() => ref.read(updateStatusProvider.notifier).check();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsReleaseNotes)),
      body: _UpdateBody(
        status: ref.watch(updateStatusProvider),
        onRetry: _check,
        builder: (data) => AppRefreshIndicator(
          onRefresh: _check,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              for (final (i, release) in data.releases.indexed)
                _NotesCard(release, expanded: i == 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the check's progress or failure, or [builder]'s content once there
/// is a result.
class _UpdateBody extends StatelessWidget {
  const _UpdateBody({
    required this.status,
    required this.onRetry,
    required this.builder,
  });

  final AsyncValue<UpdateStatus?> status;
  final VoidCallback onRetry;
  final Widget Function(UpdateStatus data) builder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final data = status.value;
    if (data != null) return builder(data);
    if (status.hasError) {
      final failure = switch (status.error) {
        UpdateCheckException(:final failure) => failure,
        _ => UpdateCheckFailure.network,
      };
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                failure == UpdateCheckFailure.rateLimited
                    ? l10n.appUpdateRateLimited
                    : l10n.appUpdateCheckFailed,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onRetry, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator.adaptive(),
          const SizedBox(height: 16),
          Text(l10n.appUpdateChecking),
        ],
      ),
    );
  }
}

/// The verdict (up to date, or a newer version) and what can be done about it.
class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.data, required this.onInstall});

  final UpdateStatus data;
  final Future<void> Function(ReleaseInfo release) onInstall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = AppPalette.of(context).muted;
    final latest = data.latest;
    final installed = data.installed?.toString() ?? '';
    final android = theme.platform == TargetPlatform.android;
    final skipped =
        latest != null &&
        ref.watch(settingsProvider).skippedVersion == latest.version.toString();
    final apk = ref.watch(apkProvider);

    final (
      IconData icon,
      Color color,
      String title,
      String? subtitle,
    ) = latest == null
        ? (
            Icons.info_rounded,
            AppPalette.tileSlate,
            l10n.appUpdateNoReleases,
            null,
          )
        : data.updateAvailable
        ? (
            Icons.system_update_rounded,
            AppPalette.tileBlue,
            l10n.appUpdateAvailableTitle(latest.version.toString()),
            l10n.appUpdateAvailableBody(installed),
          )
        : (
            Icons.check_circle_rounded,
            AppPalette.tileGreen,
            l10n.appUpdateUpToDateTitle,
            l10n.appUpdateUpToDateBody(installed),
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTile(icon, color, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: muted,
                          ),
                        ),
                      if (data.updateAvailable && latest?.publishedAt != null)
                        Text(
                          l10n.appUpdateReleased(
                            latest!.publishedAt!.toLocal(),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (data.updateAvailable && latest != null) ...[
              const SizedBox(height: 20),
              if (android) ...[
                if (apk.busy)
                  _Progress(apk: apk)
                else
                  FilledButton.icon(
                    onPressed: () => onInstall(latest),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(l10n.appUpdateDownload),
                  ),
                if (_failureText(l10n, apk.failure) case final text?)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () => _open(latest.url),
                  child: Text(l10n.appUpdateViewOnGitHub),
                ),
              ] else
                FilledButton.icon(
                  onPressed: () => _open(latest.url),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(l10n.appUpdateOpenRelease),
                ),
              if (skipped) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.appUpdateSkippedNote,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                TextButton(
                  onPressed: () => ref
                      .read(settingsProvider.notifier)
                      .update((s) => s.copyWith(skippedVersion: () => null)),
                  child: Text(l10n.appUpdateUnskip),
                ),
              ] else
                TextButton(
                  onPressed: () => ref
                      .read(settingsProvider.notifier)
                      .update(
                        (s) => s.copyWith(
                          skippedVersion: () => latest.version.toString(),
                        ),
                      ),
                  child: Text(l10n.appUpdateSkip),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String? _failureText(AppLocalizations l10n, ApkFailure? failure) =>
    switch (failure) {
      null || ApkFailure.permission => null,
      ApkFailure.noApk => l10n.appUpdateErrNoApk,
      ApkFailure.download => l10n.appUpdateErrDownload,
      ApkFailure.damaged => l10n.appUpdateErrDamaged,
      ApkFailure.install => l10n.appUpdateErrInstall,
    };

Future<void> _open(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// The download's progress, with a way to stop it.
class _Progress extends ConsumerWidget {
  const _Progress({required this.apk});

  final ApkState apk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final progress = apk.progress;
    final label = apk.phase == ApkPhase.installing
        ? l10n.appUpdateInstalling
        : progress == null
        ? l10n.appUpdateDownloading
        : l10n.appUpdateDownloadingPercent((progress * 100).floor());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: apk.phase == ApkPhase.installing ? null : progress,
        ),
        if (apk.phase == ApkPhase.downloading)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: ref.read(apkProvider.notifier).cancel,
              child: Text(l10n.cancel),
            ),
          ),
      ],
    );
  }
}

/// One release: its name, date and notes (Markdown). Only the latest release
/// starts open ([expanded]); the older ones fold away until tapped.
class _NotesCard extends StatelessWidget {
  const _NotesCard(this.release, {required this.expanded});

  final ReleaseInfo release;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = AppPalette.of(context).muted;
    final date = release.publishedAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      // No divider lines above and below the open notes.
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // Keyed by release, so a refresh keeps what the user opened.
          key: ValueKey<String>(release.tag),
          initiallyExpanded: expanded,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          expandedAlignment: Alignment.topLeft,
          title: Text(
            release.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: date == null
              ? null
              : Text(
                  l10n.appUpdateReleased(date.toLocal()),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
          children: [
            if (release.notes.isEmpty)
              Text(
                l10n.appUpdateNoNotes,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              )
            else
              // GitHub's notes are Markdown, with links to pull requests.
              MarkdownBody(
                data: release.notes,
                selectable: true,
                onTapLink: (_, href, _) {
                  if (href != null) _open(href);
                },
              ),
          ],
        ),
      ),
    );
  }
}
