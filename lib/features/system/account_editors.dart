import 'package:flutter/material.dart';

import '../../core/models/system.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/dialogs.dart';
import '../../shared/ui.dart';
import '../sharing/sharing_widgets.dart';
import '../storage/storage_helpers.dart';

/// Lowercase letters, digits, `-` and `_`, starting with a letter or `_`.
bool validAccountName(String value) =>
    RegExp(r'^[a-z_][a-z0-9_-]{0,31}$').hasMatch(value);

/// Wraps an editor's fields: centred and not wider than a tablet can read.
class _EditorForm extends StatelessWidget {
  const _EditorForm({required this.formKey, required this.children});

  final GlobalKey<FormState> formKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        for (final child in children)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: child,
              ),
            ),
          ),
      ],
    ),
  );
}

typedef _UserOptions = ({List<LocalGroup> groups, Map<String, String> shells});

/// Edits a local user. Pops `true` once saved. Only the fields that changed
/// are sent. A built-in account (such as `root`) keeps its name, groups and
/// lock: the middleware refuses to change those.
class UserEditor extends StatefulWidget {
  const UserEditor({super.key, required this.session, required this.user});

  final TrueNasSession session;
  final LocalUser user;

  @override
  State<UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends State<UserEditor>
    with LoadState<UserEditor, _UserOptions> {
  LocalUser get _user => widget.user;
  final _formKey = GlobalKey<FormState>();
  late final _username = TextEditingController(text: _user.username);
  late final _fullName = TextEditingController(text: _user.fullName);
  late final _email = TextEditingController(text: _user.email ?? '');
  late final _sshKey = TextEditingController(text: _user.sshPublicKey);
  final _password = TextEditingController();
  late bool _smb = _user.smb;
  late bool _locked = _user.locked;
  late String _shell = _user.shell;
  late int? _primaryGroup = _user.primaryGroupId;
  late Set<int> _groups = {..._user.groupIds};
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _username.dispose();
    _fullName.dispose();
    _email.dispose();
    _sshKey.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Future<_UserOptions> fetch() async {
    final system = widget.session.system;
    final (groups, shells) = await (
      system.groups(builtin: true),
      system.shellChoices(),
    ).wait;
    return (groups: groups, shells: shells);
  }

  Future<void> _pickGroups(List<LocalGroup> all) async {
    final picked = await showAppDialog<Set<int>>(
      context: context,
      builder: (_) => _GroupsDialog(groups: all, selected: _groups),
    );
    if (picked != null) setState(() => _groups = picked);
  }

  Map<String, Object?> _changes() {
    final user = _user;
    String? blankToNull(String v) => v.trim().isEmpty ? null : v.trim();
    return {
      if (!user.builtin && _username.text.trim() != user.username)
        'username': _username.text.trim(),
      if (_fullName.text.trim() != user.fullName)
        'full_name': _fullName.text.trim(),
      if (_email.text.trim() != (user.email ?? ''))
        'email': blankToNull(_email.text),
      if (_password.text.isNotEmpty) 'password': _password.text,
      if (!user.builtin && _smb != user.smb) 'smb': _smb,
      if (!user.builtin && _locked != user.locked) 'locked': _locked,
      if (_shell != user.shell && _shell.isNotEmpty) 'shell': _shell,
      if (_sshKey.text.trim() != user.sshPublicKey.trim())
        'sshpubkey': blankToNull(_sshKey.text),
      if (!user.builtin &&
          _primaryGroup != null &&
          _primaryGroup != user.primaryGroupId)
        'group': _primaryGroup,
      if (!user.builtin &&
          (_groups.length != user.groupIds.length ||
              !_groups.containsAll(user.groupIds)))
        'groups': _groups.toList()..sort(),
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final changes = _changes();
    if (changes.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    final ok = await runWithFeedback(
      context,
      () => widget.session.system.updateUser(_user.id, changes),
      success: l10n.userSaved(_user.username),
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
        title: Text(l10n.userEdit),
        actions: [
          TextButton(
            onPressed: data == null || _saving ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: AsyncBody<_UserOptions>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (options) {
          final user = _user;
          final groupNames = {for (final g in options.groups) g.id: g.name};
          final shells = {
            ...options.shells,
            if (_user.shell.isNotEmpty && !options.shells.containsKey(_shell))
              _user.shell: _user.shell,
          };
          return _EditorForm(
            formKey: _formKey,
            children: [
              if (!user.builtin)
                TextFormField(
                  controller: _username,
                  autocorrect: false,
                  decoration: InputDecoration(labelText: l10n.userUsername),
                  validator: (v) => validAccountName((v ?? '').trim())
                      ? null
                      : l10n.userUsernameInvalid,
                ),
              TextFormField(
                controller: _fullName,
                decoration: InputDecoration(labelText: l10n.userFullName),
              ),
              TextFormField(
                controller: _email,
                autocorrect: false,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.userEmail),
              ),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.userNewPassword,
                  helperText: l10n.userNewPasswordHelp,
                  suffixIcon: IconButton(
                    tooltip: _obscure ? l10n.showSecret : l10n.hideSecret,
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (shells.isNotEmpty && _shell.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: shells.containsKey(_shell) ? _shell : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.userShell),
                  items: [
                    for (final e in shells.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _shell = v ?? _shell),
                ),
              TextFormField(
                controller: _sshKey,
                autocorrect: false,
                minLines: 2,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(labelText: l10n.userSshKey),
              ),
              if (!user.builtin && groupNames.containsKey(_primaryGroup))
                DropdownButtonFormField<int>(
                  initialValue: _primaryGroup,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.userPrimaryGroup),
                  items: [
                    for (final g in options.groups)
                      DropdownMenuItem(value: g.id, child: Text(g.name)),
                  ],
                  onChanged: (v) => setState(() => _primaryGroup = v),
                ),
              if (!user.builtin)
                GroupedCard(
                  children: [
                    ListTile(
                      title: Text(l10n.userExtraGroups),
                      subtitle: Text(
                        _groups.isEmpty
                            ? l10n.userExtraGroupsNone
                            : (_groups
                                      .map((id) => groupNames[id] ?? '$id')
                                      .toList()
                                    ..sort())
                                  .join(', '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickGroups(options.groups),
                    ),
                  ],
                ),
              if (!user.builtin)
                GroupedCard(
                  children: [
                    AppSwitchTile(
                      title: Text(l10n.userSmb),
                      value: _smb,
                      onChanged: (v) => setState(() => _smb = v),
                    ),
                    AppSwitchTile(
                      title: Text(l10n.userLocked),
                      value: _locked,
                      onChanged: (v) => setState(() => _locked = v),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Ticks groups; pops the chosen set of group ids.
class _GroupsDialog extends StatefulWidget {
  const _GroupsDialog({required this.groups, required this.selected});

  final List<LocalGroup> groups;
  final Set<int> selected;

  @override
  State<_GroupsDialog> createState() => _GroupsDialogState();
}

class _GroupsDialogState extends State<_GroupsDialog> {
  late final Set<int> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: Text(l10n.userExtraGroups),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final g in widget.groups)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(g.name),
                value: _selected.contains(g.id),
                onChanged: (v) => setState(
                  () =>
                      v == true ? _selected.add(g.id) : _selected.remove(g.id),
                ),
              ),
          ],
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
          label: l10n.done,
          primary: true,
          onPressed: () => Navigator.pop(context, _selected),
        ),
      ],
    );
  }
}

typedef _GroupOptions = List<LocalUser>;

/// Renames a group and chooses its members. Pops `true` once saved. A
/// built-in group keeps its name.
class GroupEditor extends StatefulWidget {
  const GroupEditor({super.key, required this.session, required this.group});

  final TrueNasSession session;
  final LocalGroup group;

  @override
  State<GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<GroupEditor>
    with LoadState<GroupEditor, _GroupOptions> {
  LocalGroup get _group => widget.group;
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: _group.name);
  late final Set<int> _members = {..._group.memberIds};
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Future<_GroupOptions> fetch() => widget.session.system.users(builtin: true);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    final renamed = !_group.builtin && name != _group.name;
    final membersChanged =
        _members.length != _group.memberIds.length ||
        !_members.containsAll(_group.memberIds);
    if (!renamed && !membersChanged) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    final ok = await runWithFeedback(
      context,
      () => widget.session.system.updateGroup(
        _group.id,
        name: renamed ? name : null,
        members: membersChanged ? (_members.toList()..sort()) : null,
      ),
      success: l10n.groupSaved(renamed ? name : _group.name),
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
        title: Text(l10n.groupEdit),
        actions: [
          TextButton(
            onPressed: data == null || _saving ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: AsyncBody<_GroupOptions>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (users) {
          // System accounts only show when they are already members, so
          // the list stays short and nobody is dropped by saving.
          final shown = [
            for (final u in users)
              if (!u.builtin || _members.contains(u.id)) u,
          ];
          return _EditorForm(
            formKey: _formKey,
            children: [
              if (!_group.builtin)
                TextFormField(
                  controller: _name,
                  autocorrect: false,
                  decoration: InputDecoration(labelText: l10n.groupName),
                  validator: (v) => validAccountName((v ?? '').trim())
                      ? null
                      : l10n.userUsernameInvalid,
                ),
              Text(
                l10n.groupMembersTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (shown.isEmpty)
                EmptyCard(l10n.usersEmpty)
              else
                GroupedCard(
                  children: [
                    for (final u in shown)
                      CheckboxListTile(
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(u.username),
                        subtitle: u.fullName.isEmpty ? null : Text(u.fullName),
                        value: _members.contains(u.id),
                        onChanged: (v) => setState(
                          () => v == true
                              ? _members.add(u.id)
                              : _members.remove(u.id),
                        ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
