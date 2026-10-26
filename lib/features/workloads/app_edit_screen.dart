import 'package:flutter/material.dart';

import '../../core/models/app_catalog.dart';
import '../../core/models/workloads.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../sharing/sharing_widgets.dart';
import '../storage/storage_helpers.dart';
import 'app_config_state.dart';
import 'app_install_screen.dart';

/// An app's current values with the form of its installed version.
class _Current {
  const _Current(this.values, this.schema);

  final Map<String, dynamic> values;
  final AppConfigSchema schema;
}

/// Edits an installed app's configuration and applies it, which redeploys
/// the app. A custom app has no form: its Docker Compose config is edited as
/// JSON. Pops `true` once the server has taken the change.
class AppEditScreen extends StatefulWidget {
  const AppEditScreen({super.key, required this.session, required this.app});

  final TrueNasSession session;
  final TrueNasApp app;

  @override
  State<AppEditScreen> createState() => _AppEditScreenState();
}

class _AppEditScreenState extends State<AppEditScreen>
    with LoadState<AppEditScreen, _Current>, AppConfigState<AppEditScreen> {
  var _saving = false;
  var _started = false;

  @override
  Future<_Current> fetch() async {
    final api = widget.session.workloads;
    final app = widget.app;
    final catalogName = app.catalogName;
    final train = app.train;
    final (config, details) = await (
      api.appConfig(app.name),
      app.customApp || catalogName == null || train == null
          ? Future<CatalogAppDetails?>.value()
          : api
                .catalogDetails(catalogName, train)
                .then<CatalogAppDetails?>(
                  (d) => d,
                  // Without the catalog the values can still be edited as JSON.
                  onError: (_) => null,
                ),
    ).wait;
    final version = details?.version(app.chartVersion) ?? details?.latest;
    final schema = version?.schema ?? const AppConfigSchema();
    if (!_started) {
      _started = true;
      startConfig(schema, config);
    }
    return _Current(config, schema);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final payload = collectValues();
    if (payload == null) return;
    setState(() => _saving = true);
    final name = widget.app.name;
    final ok = await submitAppJob(
      context,
      widget.session,
      start: () => widget.app.customApp
          ? widget.session.workloads.updateApp(name, compose: payload)
          : widget.session.workloads.updateApp(name, values: payload),
      doneText: l10n.appConfigSaved(name),
      runningText: l10n.appConfigApplying(name),
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
        title: Text(l10n.appEditTitle(widget.app.name)),
        actions: [
          ?jsonToggle(),
          TextButton(
            onPressed: data == null || _saving ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: AsyncBody<_Current>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (_) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_saving) const LinearProgressIndicator(),
                    if (!jsonMode || !hasForm) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          widget.app.customApp
                              ? l10n.appEditCustomNote
                              : hasForm
                              ? l10n.appEditRestartNote
                              : l10n.appEditNoFormNote,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                    configBody(
                      editing: true,
                      jsonLabel: widget.app.customApp
                          ? l10n.appCustomComposeJson
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
