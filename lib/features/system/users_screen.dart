import 'package:flutter/material.dart';

import '../../core/models/system.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/viz_colors.dart';
import '../../shared/widgets.dart';
import '../sharing/sharing_widgets.dart';
import '../storage/storage_helpers.dart';
import '../../shared/dialogs.dart';

typedef _AccountsData = (List<LocalUser>, List<LocalGroup>);

/// Local users and groups: list, add, lock and delete.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen>
    with LoadState<UsersScreen, _AccountsData> {
  TrueNasSession get _session => widget.session;
  bool _showBuiltin = false;

  @override
  Future<_AccountsData> fetch() => (
    _session.system.users(builtin: _showBuiltin),
    _session.system.groups(builtin: _showBuiltin),
  ).wait;

  Future<void> _createUser() async {
    final l10n = AppLocalizations.of(context);
    final request = await showAppDialog<_NewUser>(
      context: context,
      builder: (_) => const _NewUserDialog(),
    );
    if (request == null || !mounted) return;
    final ok = await runWithFeedback(
      context,
      () => _session.system.createUser(
        username: request.username,
        fullName: request.fullName,
        password: request.password,
        smb: request.smb,
      ),
      success: l10n.userCreated(request.username),
    );
    if (ok) await load();
  }

  Future<void> _createGroup() async {
    final l10n = AppLocalizations.of(context);
    final name = await showAppDialog<String>(
      context: context,
      builder: (_) => _NameDialog(
        title: l10n.groupCreate,
        label: l10n.groupName,
        validate: (v) => _validName(v) ? null : l10n.userUsernameInvalid,
      ),
    );
    if (name == null || !mounted) return;
    final ok = await runWithFeedback(
      context,
      () => _session.system.createGroup(name),
      success: l10n.groupCreated(name),
    );
    if (ok) await load();
  }

  Future<void> _setLocked(LocalUser user, bool locked) async {
    final l10n = AppLocalizations.of(context);
    final ok = await runWithFeedback(
      context,
      () => _session.system.setUserLocked(user.id, locked),
      success: locked
          ? l10n.userLockedMessage(user.username)
          : l10n.userUnlockedMessage(user.username),
    );
    if (ok) await load();
  }

  Future<void> _deleteUser(LocalUser user) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.userDeleteTitle(user.username),
      body: l10n.userDeleteBody,
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await runWithFeedback(
      context,
      () => _session.system.deleteUser(user.id),
      success: l10n.userDeleted(user.username),
    );
    if (ok) await load();
  }

  Future<void> _deleteGroup(LocalGroup group) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.groupDeleteTitle(group.name),
      body: l10n.groupDeleteBody,
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await runWithFeedback(
      context,
      () => _session.system.deleteGroup(group.id),
      success: l10n.groupDeleted(group.name),
    );
    if (ok) await load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(l10n.usersTitle),
            bottom: TabBar(
              tabs: [
                Tab(text: l10n.usersTitle),
                Tab(text: l10n.groupsTitle),
              ],
            ),
          ),
          floatingActionButton: data == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => DefaultTabController.of(context).index == 0
                      ? _createUser()
                      : _createGroup(),
                  icon: const Icon(Icons.add),
                  label: AnimatedBuilder(
                    animation: DefaultTabController.of(context),
                    builder: (context, _) => Text(
                      DefaultTabController.of(context).index == 0
                          ? l10n.userCreate
                          : l10n.groupCreate,
                    ),
                  ),
                ),
          body: AsyncBody<_AccountsData>(
            value: data,
            error: error,
            onRefresh: load,
            builder: (data) {
              final (users, groups) = data;
              final builtinToggle = AppSwitchTile(
                title: Text(l10n.usersShowBuiltin),
                value: _showBuiltin,
                onChanged: (v) {
                  setState(() => _showBuiltin = v);
                  load();
                },
              );
              return TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    children: [
                      GroupedCard(children: [builtinToggle]),
                      const SizedBox(height: 12),
                      if (users.isEmpty) EmptyCard(l10n.usersEmpty),
                      if (users.isNotEmpty)
                        GroupedCard(
                          indent: 72,
                          children: [
                            for (final user in users)
                              _UserTile(
                                user: user,
                                onLock: (v) => _setLocked(user, v),
                                onDelete: () => _deleteUser(user),
                              ),
                          ],
                        ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    children: [
                      GroupedCard(children: [builtinToggle]),
                      const SizedBox(height: 12),
                      if (groups.isEmpty) EmptyCard(l10n.groupsEmpty),
                      if (groups.isNotEmpty)
                        GroupedCard(
                          indent: 72,
                          children: [
                            for (final group in groups)
                              ListTile(
                                leading: const IconTile(
                                  Icons.group_rounded,
                                  AppPalette.tileTeal,
                                  size: 40,
                                ),
                                title: Text(group.name),
                                subtitle: Text(
                                  'GID ${group.gid} · '
                                  '${l10n.groupMembers(group.members)}',
                                ),
                                trailing: group.builtin
                                    ? Text(l10n.userBuiltin)
                                    : IconButton(
                                        tooltip: l10n.delete,
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => _deleteGroup(group),
                                      ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

bool _validName(String value) =>
    RegExp(r'^[a-z_][a-z0-9_-]{0,31}$').hasMatch(value);

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.onLock,
    required this.onDelete,
  });

  final LocalUser user;
  final ValueChanged<bool> onLock;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: AppPalette.tileBlue.withValues(alpha: 0.14),
        foregroundColor: AppPalette.tileBlue,
        child: Text(
          user.username.characters.first.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(user.username),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              if (user.fullName.isNotEmpty) user.fullName,
              'UID ${user.uid}',
            ].join(' · '),
          ),
          if (user.locked || user.twoFactor || user.builtin)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 12,
                children: [
                  if (user.locked)
                    StatusLabel(
                      icon: Icons.lock,
                      color: VizColors.warning,
                      label: l10n.userLocked,
                    ),
                  if (user.twoFactor)
                    StatusLabel(
                      icon: Icons.verified_user_outlined,
                      color: VizColors.good,
                      label: l10n.userTwoFactor,
                    ),
                  if (user.builtin)
                    StatusLabel(
                      icon: Icons.settings_outlined,
                      color: muted,
                      label: l10n.userBuiltin,
                    ),
                ],
              ),
            ),
        ],
      ),
      trailing: user.builtin
          ? null
          : AppPopupMenu<String>(
              onSelected: (value) => switch (value) {
                'lock' => onLock(!user.locked),
                _ => onDelete(),
              },
              entries: [
                menuEntry(
                  'lock',
                  user.locked ? l10n.userUnlock : l10n.userLock,
                ),
                menuEntry('delete', l10n.delete, destructive: true),
              ],
            ),
    );
  }
}

class _NewUser {
  const _NewUser(this.username, this.fullName, this.password, this.smb);

  final String username;
  final String fullName;
  final String password;
  final bool smb;
}

class _NewUserDialog extends StatefulWidget {
  const _NewUserDialog();

  @override
  State<_NewUserDialog> createState() => _NewUserDialogState();
}

class _NewUserDialogState extends State<_NewUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _fullName = TextEditingController();
  final _password = TextEditingController();
  bool _smb = true;
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _fullName.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _NewUser(
        _username.text.trim(),
        _fullName.text.trim(),
        _password.text,
        _smb,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: Text(l10n.userCreate),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _username,
                autofocus: true,
                autocorrect: false,
                decoration: InputDecoration(labelText: l10n.userUsername),
                validator: (v) => _validName(v?.trim() ?? '')
                    ? null
                    : l10n.userUsernameInvalid,
              ),
              TextFormField(
                controller: _fullName,
                decoration: InputDecoration(labelText: l10n.userFullName),
              ),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.userPassword,
                  suffixIcon: IconButton(
                    tooltip: _obscure ? l10n.showSecret : l10n.hideSecret,
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v ?? '').isEmpty ? l10n.userPasswordRequired : null,
              ),
              AppSwitchTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.userSmb),
                value: _smb,
                onChanged: (v) => setState(() => _smb = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        dialogAction(
          context,
          label: l10n.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        dialogAction(
          context,
          label: l10n.create,
          primary: true,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Asks for a single name, e.g. for a new group or API key.
class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.label,
    required this.validate,
  });

  final String title;
  final String label;
  final String? Function(String) validate;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _name.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _name,
          autofocus: true,
          autocorrect: false,
          decoration: InputDecoration(labelText: widget.label),
          validator: (v) => widget.validate(v?.trim() ?? ''),
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        dialogAction(
          context,
          label: l10n.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        dialogAction(
          context,
          label: l10n.create,
          primary: true,
          onPressed: _submit,
        ),
      ],
    );
  }
}
