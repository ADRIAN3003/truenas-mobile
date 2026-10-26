import 'package:flutter/material.dart';

import '../../core/models/app_catalog.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../sharing/sharing_widgets.dart';
import '../storage/storage_helpers.dart';
import 'app_icon.dart';
import 'app_install_screen.dart';

class _Catalog {
  const _Catalog({
    required this.apps,
    required this.docker,
    required this.canSync,
  });

  final List<CatalogApp> apps;
  final DockerState docker;
  final bool canSync;
}

/// The apps the catalog offers, searchable by name and by category. Pops
/// `true` when something was installed.
class AppCatalogScreen extends StatefulWidget {
  const AppCatalogScreen({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<AppCatalogScreen> createState() => _AppCatalogScreenState();
}

class _AppCatalogScreenState extends State<AppCatalogScreen>
    with LoadState<AppCatalogScreen, _Catalog> {
  final _search = TextEditingController();
  String? _category;
  var _syncing = false;

  @override
  Future<_Catalog> fetch() async {
    final api = widget.session.workloads;
    final (apps, docker, canSync) = await (
      api.catalogApps(),
      api.dockerState(),
      api.canSyncCatalog(),
    ).wait;
    return _Catalog(apps: apps, docker: docker, canSync: canSync);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _syncing = true);
    final ok = await runWithFeedback(
      context,
      widget.session.workloads.syncCatalog,
      success: l10n.catalogRefreshed,
    );
    if (!mounted) return;
    setState(() => _syncing = false);
    if (ok) await load();
  }

  Future<void> _open(Widget screen) async {
    final installed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => screen),
    );
    if (installed == true && mounted) Navigator.pop(context, true);
  }

  bool _matches(CatalogApp app) {
    if (_category != null && !app.categories.contains(_category)) return false;
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return app.title.toLowerCase().contains(query) ||
        app.name.toLowerCase().contains(query) ||
        (app.description ?? '').toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSync = data?.canSync ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.catalogTitle),
        actions: [
          if (canSync)
            _syncing
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: l10n.catalogRefresh,
                    icon: const Icon(Icons.sync),
                    onPressed: _sync,
                  ),
        ],
      ),
      body: AsyncBody<_Catalog>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (catalog) => _list(context, catalog),
      ),
    );
  }

  Widget _list(BuildContext context, _Catalog catalog) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final categories = <String>{
      for (final app in catalog.apps) ...app.categories,
    }.toList()..sort();
    final shown = [
      for (final app in catalog.apps)
        if (_matches(app)) app,
    ];
    final canInstall = catalog.docker.canInstall;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (!canInstall)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      catalog.docker == DockerState.unconfigured
                          ? l10n.dockerUnconfigured
                          : l10n.dockerNotRunning,
                    ),
                  ),
                ],
              ),
            ),
          ),
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l10n.catalogSearch,
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.clearSearch,
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(_search.clear),
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final category in [null, ...categories])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category ?? l10n.catalogAll),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (canInstall)
          ...groupedSection(l10n.catalogCustomAppSection, [
            NavRow(
              icon: Icons.code_rounded,
              color: AppPalette.tileTeal,
              title: l10n.catalogCustomApp,
              subtitle: l10n.catalogCustomAppHint,
              onTap: () => _open(CustomAppScreen(session: widget.session)),
            ),
          ]),
        ...groupedSection(
          l10n.catalogAppsSection(shown.length),
          empty: l10n.catalogEmpty,
          [
            for (final app in shown)
              ListTile(
                leading: AppIcon(url: app.iconUrl),
                title: Text(app.title),
                subtitle: Text(
                  [
                    if (app.train != 'stable') app.train,
                    if (app.description != null && app.description!.isNotEmpty)
                      app.description!,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: app.installed
                    ? Tooltip(
                        message: l10n.catalogInstalled,
                        child: Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : const Chevron(),
                onTap: canInstall
                    ? () => _open(
                        AppInstallScreen(session: widget.session, app: app),
                      )
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}
