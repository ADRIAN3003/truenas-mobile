import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/logging/app_log.dart';
import '../../core/logging/log_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';

/// The app's error log: what went wrong on this phone, newest first, with
/// copy, share and clear. Everything in it is already scrubbed of passwords
/// and keys.
class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  @override
  void initState() {
    super.initState();
    // The background check logs from its own isolate.
    ref.read(appLogProvider).reload();
  }

  /// Who, what and when, above the entries of a copied or shared log.
  Future<String> _header() async {
    var version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version} (${info.buildNumber})';
    } catch (_) {}
    return [
      'TrueNAS Mobile log',
      if (version.isNotEmpty) 'App: $version',
      'Phone: ${Platform.operatingSystem} '
          '${Platform.operatingSystemVersion.split('\n').first}',
      'Exported: ${DateTime.now().toUtc().toIso8601String()}',
    ].join('\n');
  }

  Future<String> _text() async =>
      ref.read(appLogProvider).export(header: await _header());

  Future<void> _copy() async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = AppLocalizations.of(context).logCopied;
    await Clipboard.setData(ClipboardData(text: await _text()));
    messenger.showSnackBar(SnackBar(content: Text(copied)));
  }

  Future<void> _share(BuildContext buttonContext) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).logShareFailed;
    final sharer = ref.read(logSharerProvider);
    // An iPad anchors the share popover to the button.
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await sharer.share(await _text(), origin: origin);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context);
    final log = ref.read(appLogProvider);
    final confirmed = await confirmAction(
      context,
      title: l10n.logClear,
      body: l10n.logClearBody,
      confirmLabel: l10n.logClearConfirm,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed) await log.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(logEntriesProvider).value ?? const <LogEntry>[];
    final empty = entries.isEmpty;
    final newestFirst = entries.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.logTitle),
        actions: [
          IconButton(
            tooltip: l10n.copy,
            icon: const Icon(Icons.copy_rounded),
            onPressed: empty ? null : _copy,
          ),
          Builder(
            builder: (buttonContext) => IconButton(
              tooltip: l10n.logShare,
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: empty ? null : () => _share(buttonContext),
            ),
          ),
          IconButton(
            tooltip: l10n.logClear,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: empty ? null : _clear,
          ),
        ],
      ),
      body: empty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const IconTile(
                      Icons.fact_check_outlined,
                      AppPalette.tileSlate,
                      size: 72,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.logEmptyTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.logEmptyBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppPalette.of(context).muted),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
                  child: Text(
                    l10n.logNote,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppPalette.of(context).muted),
                  ),
                ),
                GroupedCard(
                  indent: 16,
                  children: [for (final entry in newestFirst) _Entry(entry)],
                ),
              ],
            ),
    );
  }
}

/// One entry: its message, when and where it happened, and the stack trace
/// when there is one (tap to open).
class _Entry extends StatelessWidget {
  const _Entry(this.entry);

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final locale = Localizations.localeOf(context).toString();
    final (icon, color) = switch (entry.level) {
      LogLevel.error => (Icons.error_rounded, palette.critical),
      LogLevel.warning => (Icons.warning_amber_rounded, palette.warning),
      LogLevel.info => (Icons.info_outline_rounded, palette.info),
    };
    final when = DateFormat.yMd(locale).add_Hms().format(entry.time.toLocal());
    final theme = Theme.of(context);
    final subtitle = Text(
      '$when · ${entry.source}',
      style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
    );
    final message = SelectableText(
      entry.message,
      style: theme.textTheme.bodyMedium,
    );
    final details = entry.details;
    if (details == null) {
      return ListTile(
        leading: Icon(icon, color: color),
        title: message,
        subtitle: subtitle,
      );
    }
    return ExpansionTile(
      leading: Icon(icon, color: color),
      title: Text(entry.message, maxLines: 3, overflow: TextOverflow.ellipsis),
      subtitle: subtitle,
      shape: const Border(),
      collapsedShape: const Border(),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        SelectableText(
          details,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
      ],
    );
  }
}
