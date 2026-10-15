import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/models/system.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/viz_colors.dart';
import '../../shared/widgets.dart';
import '../sharing/sharing_widgets.dart';
import '../storage/storage_helpers.dart';

/// API keys: list, add (showing the secret once) and delete.
class ApiKeysScreen extends StatefulWidget {
  const ApiKeysScreen({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends State<ApiKeysScreen>
    with LoadState<ApiKeysScreen, List<ApiKeyInfo>> {
  TrueNasSession get _session => widget.session;

  @override
  Future<List<ApiKeyInfo>> fetch() => _session.system.apiKeys();

  Future<void> _create() async {
    final users = await _session.system.users(builtin: true);
    if (!mounted) return;
    final usernames = [
      for (final u in users)
        if (!u.locked) u.username,
    ];
    final current = _session.userInfo?['pw_name'] as String?;
    final request = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _NewKeyDialog(
        usernames: usernames,
        initialUser: usernames.contains(current)
            ? current!
            : usernames.firstOrNull,
      ),
    );
    if (request == null || !mounted) return;
    String? key;
    final ok = await runWithFeedback(context, () async {
      key = await _session.system.createApiKey(request.$1, request.$2);
    });
    if (!ok || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _KeyCreatedDialog(secret: key!),
    );
    if (mounted) await load();
  }

  Future<void> _delete(ApiKeyInfo key) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.apiKeyDeleteTitle(key.name),
      body: l10n.apiKeyDeleteBody,
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await runWithFeedback(
      context,
      () => _session.system.deleteApiKey(key.id),
      success: l10n.apiKeyDeleted(key.name),
    );
    if (ok) await load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.apiKeysTitle)),
      floatingActionButton: data == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: Text(l10n.apiKeyCreate),
            ),
      body: AsyncBody<List<ApiKeyInfo>>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (keys) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          children: [
            if (keys.isEmpty) EmptyCard(l10n.apiKeysEmpty),
            if (keys.isNotEmpty)
              GroupedCard(
                indent: 72,
                children: [
                  for (final key in keys)
                    ListTile(
                      leading: const IconTile(
                        Icons.key_rounded,
                        AppPalette.tileOrange,
                        size: 40,
                      ),
                      title: Text(key.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              ?key.username,
                              if (key.createdAt case final created?)
                                l10n.apiKeyCreatedOn(
                                  DateFormat.yMMMd(locale).format(created),
                                ),
                              if (key.expiresAt case final expires?)
                                l10n.apiKeyExpires(
                                  DateFormat.yMMMd(locale).format(expires),
                                ),
                            ].join(' · '),
                          ),
                          if (key.revoked)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: StatusLabel(
                                icon: Icons.block,
                                color: VizColors.critical,
                                label: l10n.apiKeyRevoked,
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        tooltip: l10n.delete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(key),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _NewKeyDialog extends StatefulWidget {
  const _NewKeyDialog({required this.usernames, required this.initialUser});

  final List<String> usernames;
  final String? initialUser;

  @override
  State<_NewKeyDialog> createState() => _NewKeyDialogState();
}

class _NewKeyDialogState extends State<_NewKeyDialog> {
  final _name = TextEditingController();
  late String? _user = widget.initialUser;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = _user;
    final name = _name.text.trim();
    return AlertDialog(
      title: Text(l10n.apiKeyCreate),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.apiKeyName),
          ),
          DropdownButtonFormField<String>(
            initialValue: user,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.apiKeyUser),
            items: [
              for (final u in widget.usernames)
                DropdownMenuItem(value: u, child: Text(u)),
            ],
            onChanged: (u) => setState(() => _user = u),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: name.isEmpty || user == null
              ? null
              : () => Navigator.pop(context, (name, user)),
          child: Text(l10n.create),
        ),
      ],
    );
  }
}

/// Shows a new key's secret, which the server never returns again.
class _KeyCreatedDialog extends StatelessWidget {
  const _KeyCreatedDialog({required this.secret});

  final String secret;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    return AlertDialog(
      title: Text(l10n.apiKeyCreatedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.apiKeyCreatedBody),
          const SizedBox(height: 16),
          SelectableText(
            secret,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy),
          label: Text(l10n.copy),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: secret));
            messenger.showSnackBar(SnackBar(content: Text(l10n.apiKeyCopied)));
          },
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.done),
        ),
      ],
    );
  }
}
