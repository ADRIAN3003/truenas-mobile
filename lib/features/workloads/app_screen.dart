import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/workloads_api.dart';
import '../../core/models/workloads.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../storage/storage_helpers.dart';
import 'app_icon.dart';
import 'workload_widgets.dart';

/// One app: version, upgrade, web interfaces, images and actions.
class AppScreen extends StatefulWidget {
  const AppScreen({super.key, required this.session, required this.app});

  final TrueNasSession session;
  final TrueNasApp app;

  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> {
  late TrueNasApp _app = widget.app;
  bool _busy = false;

  Future<void> _reload() async {
    final apps = await widget.session.workloads.apps();
    final app = apps.where((a) => a.name == _app.name).firstOrNull;
    if (!mounted) return;
    if (app == null) {
      Navigator.pop(context);
    } else {
      setState(() => _app = app);
    }
  }

  Future<void> _run(WorkloadAction action) async {
    final ok = await runWorkloadAction(
      context,
      name: _app.name,
      action: action,
      upgradeFrom: _app.version,
      upgradeTo: _app.latestVersion,
      run: () => widget.session.workloads.appAction(_app.name, action),
      onConfirmed: () => setState(() => _busy = true),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok && action == WorkloadAction.delete) {
      Navigator.pop(context);
    } else {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final app = _app;
    final actions = actionsFor(
      app.state,
      supported: [
        WorkloadAction.start,
        WorkloadAction.stop,
        WorkloadAction.restart,
        if (app.upgradeAvailable) WorkloadAction.upgrade,
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(app.name),
        actions: [
          IconButton(
            tooltip: l10n.actionDelete,
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy ? null : () => _run(WorkloadAction.delete),
          ),
        ],
      ),
      body: AppRefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppIcon(url: app.iconUrl, size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            app.title ?? app.name,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        WorkloadStateLabel(state: app.state),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InfoRow(l10n.appVersion, app.version),
                    if (app.upgradeAvailable && app.latestVersion != null)
                      InfoRow(l10n.appLatestVersion, app.latestVersion!),
                    InfoRow(l10n.appContainersRunning, '${app.containers}'),
                    if (app.customApp) InfoRow(l10n.appCustom, '✓'),
                    if (app.imageUpdatesAvailable)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l10n.appImageUpdates,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (_busy)
                      const LinearProgressIndicator()
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final action in actions)
                            action == WorkloadAction.upgrade
                                ? FilledButton.icon(
                                    onPressed: () => _run(action),
                                    icon: const Icon(Icons.upgrade),
                                    label: Text(actionLabel(l10n, action)),
                                  )
                                : OutlinedButton(
                                    onPressed: () => _run(action),
                                    child: Text(actionLabel(l10n, action)),
                                  ),
                          if (app.state.isUp ||
                              app.state == WorkloadState.crashed)
                            OutlinedButton.icon(
                              onPressed: () => openAppLogs(
                                context,
                                widget.session,
                                app.name,
                              ),
                              icon: const Icon(Icons.article_outlined),
                              label: Text(l10n.appLogsTitle),
                            ),
                          if (app.state == WorkloadState.running)
                            OutlinedButton.icon(
                              onPressed: () => openAppShell(
                                context,
                                widget.session,
                                app.name,
                              ),
                              icon: const Icon(Icons.terminal),
                              label: Text(l10n.shellTitle),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (app.portals.isNotEmpty) ...[
              SectionHeader(l10n.appPortals),
              GroupedCard(
                indent: 72,
                children: [
                  for (final MapEntry(key: label, value: url)
                      in app.portals.entries)
                    ListTile(
                      leading: const IconTile(
                        Icons.open_in_browser_rounded,
                        AppPalette.tileBlue,
                        size: 40,
                      ),
                      title: Text(label),
                      subtitle: SelectableText(url),
                      trailing: IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .copyButtonLabel,
                        icon: const Icon(Icons.copy),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: url));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(l10n.copied)));
                        },
                      ),
                    ),
                ],
              ),
            ],
            if (app.images.isNotEmpty) ...[
              SectionHeader(l10n.appImages),
              GroupedCard(
                indent: 56,
                children: [
                  for (final image in app.images)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.layers_rounded,
                        color: AppPalette.of(context).muted,
                      ),
                      title: Text(image),
                    ),
                ],
              ),
            ],
            if (app.notes != null && app.notes!.trim().isNotEmpty) ...[
              SectionHeader(l10n.appNotes),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  // Catalog notes are Markdown, often with links.
                  child: MarkdownBody(
                    data: app.notes!.trim(),
                    selectable: true,
                    onTapLink: (_, href, _) {
                      final uri = href == null ? null : Uri.tryParse(href);
                      if (uri != null) {
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
