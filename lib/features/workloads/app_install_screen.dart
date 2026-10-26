import 'package:flutter/material.dart';

import '../../core/models/app_catalog.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/connect_dialogs.dart';
import '../../shared/haptics.dart';
import '../sharing/sharing_widgets.dart';
import '../storage/storage_helpers.dart';
import 'app_config_state.dart';
import 'app_icon.dart';

/// Instance names are labels: lowercase letters, digits and hyphens, starting
/// with a letter.
final _nameShape = RegExp(r'^[a-z]([-a-z0-9]*[a-z0-9])?$');

/// Whether [name] is something the server takes as an app name.
bool validAppName(String name) =>
    name.length <= 40 && _nameShape.hasMatch(name);

/// Starts the install or update job with [start], waits a few seconds for the
/// server to refuse it (a bad value fails the job within a second or so), and
/// says how it went. True once the server took it; the work carries on there.
Future<bool> submitAppJob(
  BuildContext context,
  TrueNasSession session, {
  required Future<int> Function() start,
  required String doneText,
  required String runningText,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  try {
    final finished = await session.workloads.settleJob(await start());
    Haptics.confirm();
    messenger.showSnackBar(
      SnackBar(content: Text(finished ? doneText : runningText)),
    );
    return true;
  } catch (error) {
    Haptics.warning();
    messenger.showSnackBar(
      SnackBar(content: Text(describeConnectError(l10n, error))),
    );
    return false;
  }
}

/// A form column that stays readable on a tablet.
Widget _centered(Widget child) => Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 720),
    child: child,
  ),
);

/// Installs a catalog app: its name and version, then the settings its
/// catalog entry asks for. Pops `true` once the server has taken the job.
class AppInstallScreen extends StatefulWidget {
  const AppInstallScreen({super.key, required this.session, required this.app});

  final TrueNasSession session;
  final CatalogApp app;

  @override
  State<AppInstallScreen> createState() => _AppInstallScreenState();
}

class _AppInstallScreenState extends State<AppInstallScreen>
    with
        LoadState<AppInstallScreen, CatalogAppDetails>,
        AppConfigState<AppInstallScreen> {
  late final _name = TextEditingController(text: widget.app.name);
  CatalogVersion? _version;
  var _saving = false;
  var _nameShown = false;

  @override
  Future<CatalogAppDetails> fetch() async {
    final details = await widget.session.workloads.catalogDetails(
      widget.app.name,
      widget.app.train,
    );
    if (_version == null) {
      _version = details.latest;
      startConfig(_version?.schema ?? const AppConfigSchema());
    }
    return details;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _install() async {
    final l10n = AppLocalizations.of(context);
    final version = _version;
    final name = _name.text.trim();
    if (!validAppName(name)) {
      setState(() => _nameShown = true);
      return;
    }
    final payload = collectValues();
    if (payload == null || version == null) return;
    setState(() => _saving = true);
    final ok = await submitAppJob(
      context,
      widget.session,
      start: () => widget.session.workloads.installApp(
        name: name,
        catalogApp: widget.app.name,
        train: widget.app.train,
        version: version.version,
        values: payload,
      ),
      doneText: l10n.appInstalled(name),
      runningText: l10n.appInstalling(name),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final app = widget.app;
    return Scaffold(
      appBar: AppBar(
        title: Text(app.title),
        actions: [
          ?jsonToggle(),
          TextButton(
            onPressed: data == null || _saving ? null : _install,
            child: Text(l10n.appInstallButton),
          ),
        ],
      ),
      body: AsyncBody<CatalogAppDetails>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (details) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _centered(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context, details),
                  if (_saving) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    autocorrect: false,
                    enabled: !_saving,
                    decoration: InputDecoration(
                      labelText: l10n.appInstallName,
                      helperText: l10n.appInstallNameHelp,
                      errorText: _nameShown && !validAppName(_name.text.trim())
                          ? l10n.appInstallNameInvalid
                          : null,
                    ),
                    onChanged: (_) {
                      if (_nameShown) setState(() {});
                    },
                  ),
                  if (details.versions.length > 1) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _version?.version,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.appInstallVersion,
                      ),
                      items: [
                        for (final v in details.versions)
                          DropdownMenuItem(
                            value: v.version,
                            child: Text(
                              v.humanVersion == null ||
                                      v.humanVersion == v.version
                                  ? v.version
                                  : '${v.humanVersion} (${v.version})',
                            ),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() {
                              _version = details.version(v);
                              changeSchema(
                                _version?.schema ?? const AppConfigSchema(),
                              );
                            }),
                    ),
                  ],
                  const SizedBox(height: 8),
                  configBody(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, CatalogAppDetails details) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final app = widget.app;
    final description = details.app.description ?? app.description;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(url: app.iconUrl ?? details.app.iconUrl, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(app.title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(description),
            ],
            const SizedBox(height: 8),
            InfoRow(
              l10n.appVersion,
              _version?.humanVersion ?? _version?.version ?? '',
            ),
            InfoRow(l10n.appInstallTrain, app.train),
            if (app.installed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.catalogInstalledNote,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Installs a custom app from a Docker Compose file.
class CustomAppScreen extends StatefulWidget {
  const CustomAppScreen({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<CustomAppScreen> createState() => _CustomAppScreenState();
}

class _CustomAppScreenState extends State<CustomAppScreen> {
  final _name = TextEditingController();
  final _compose = TextEditingController();
  var _saving = false;
  var _showProblems = false;

  @override
  void dispose() {
    _name.dispose();
    _compose.dispose();
    super.dispose();
  }

  Future<void> _install() async {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    final compose = _compose.text;
    if (!validAppName(name) || compose.trim().isEmpty) {
      setState(() => _showProblems = true);
      return;
    }
    setState(() => _saving = true);
    final ok = await submitAppJob(
      context,
      widget.session,
      start: () => widget.session.workloads.installCustomApp(
        name: name,
        compose: compose,
      ),
      doneText: l10n.appInstalled(name),
      runningText: l10n.appInstalling(name),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.catalogCustomApp),
        actions: [
          TextButton(
            onPressed: _saving ? null : _install,
            child: Text(l10n.appInstallButton),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _centered(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_saving) const LinearProgressIndicator(),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  autocorrect: false,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: l10n.appInstallName,
                    helperText: l10n.appInstallNameHelp,
                    errorText: _showProblems && !validAppName(_name.text.trim())
                        ? l10n.appInstallNameInvalid
                        : null,
                  ),
                  onChanged: (_) {
                    if (_showProblems) setState(() {});
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _compose,
                  enabled: !_saving,
                  minLines: 12,
                  maxLines: 40,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    labelText: l10n.appCustomCompose,
                    helperText: l10n.appCustomComposeHelp,
                    helperMaxLines: 3,
                    alignLabelWithHint: true,
                    errorText: _showProblems && _compose.text.trim().isEmpty
                        ? l10n.validationRequired
                        : null,
                  ),
                  onChanged: (_) {
                    if (_showProblems) setState(() {});
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
