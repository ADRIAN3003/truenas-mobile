import 'package:flutter/material.dart';

import '../../core/models/api_method.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../sharing/sharing_widgets.dart';
import '../storage/storage_helpers.dart';
import 'method_screen.dart';

/// Every API method the server offers, grouped by namespace and
/// searchable, so anything without a dedicated screen is still reachable.
class ApiExplorerScreen extends StatefulWidget {
  const ApiExplorerScreen({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<ApiExplorerScreen> createState() => _ApiExplorerScreenState();
}

class _ApiExplorerScreenState extends State<ApiExplorerScreen>
    with LoadState<ApiExplorerScreen, List<ApiMethod>> {
  final _search = TextEditingController();
  String _query = '';

  @override
  Future<List<ApiMethod>> fetch() =>
      widget.session.explorer.methods(refresh: data != null);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(ApiMethod method) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => MethodScreen(session: widget.session, method: method),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.explorerTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchBar(
              controller: _search,
              hintText: l10n.explorerSearch,
              leading: const Icon(Icons.search),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    tooltip: l10n.clearSearch,
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
              ],
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
        ),
      ),
      body: AsyncBody<List<ApiMethod>>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (methods) {
          if (_query.isNotEmpty) {
            final q = _query.toLowerCase();
            final matches = methods
                .where(
                  (m) =>
                      m.name.toLowerCase().contains(q) ||
                      m.summary.toLowerCase().contains(q),
                )
                .toList();
            if (matches.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text(l10n.explorerNoMatches)),
                  ),
                ],
              );
            }
            return ListView.builder(
              itemCount: matches.length,
              itemBuilder: (context, i) => MethodTile(
                method: matches[i],
                onTap: () => _open(matches[i]),
              ),
            );
          }
          final services = <String, List<ApiMethod>>{};
          for (final m in methods) {
            (services[m.service] ??= []).add(m);
          }
          final names = services.keys.toList();
          return ListView.builder(
            itemCount: names.length,
            itemBuilder: (context, i) {
              final name = names[i];
              final list = services[name]!;
              return ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(name),
                subtitle: Text(l10n.explorerMethodCount(list.length)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text(name)),
                      body: ListView(
                        children: [
                          for (final m in list)
                            MethodTile(
                              method: m,
                              onTap: () => _open(m),
                              short: true,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// A method in a list: its name, first line of documentation and badges.
class MethodTile extends StatelessWidget {
  const MethodTile({
    super.key,
    required this.method,
    required this.onTap,
    this.short = false,
  });

  final ApiMethod method;
  final VoidCallback onTap;

  /// Show only the last part of the name, inside a namespace's list.
  final bool short;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(
        method.job
            ? Icons.work_history_outlined
            : method.readOnly
            ? Icons.visibility_outlined
            : Icons.edit_outlined,
      ),
      title: Text(short ? method.shortName : method.name),
      subtitle: method.summary.isEmpty
          ? null
          : Text(method.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: method.job ? Text(l10n.explorerJob) : null,
      onTap: onTap,
    );
  }
}
