import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../shared/ui.dart';
import '../../shared/theme.dart';
import '../../shared/viz_colors.dart';
import '../../shared/widgets.dart';
import 'sharing_widgets.dart';

/// One share in a list, with an enable switch.
class ShareTile extends StatelessWidget {
  const ShareTile({
    super.key,
    required this.icon,
    required this.title,
    required this.lines,
    required this.enabled,
    required this.locked,
    required this.readOnly,
    required this.onToggle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final bool enabled;
  final bool locked;
  final bool readOnly;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: IconTile(icon, AppPalette.tileBlue, size: 40),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Text(line, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (locked || readOnly)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 12,
                children: [
                  if (locked)
                    StatusLabel(
                      icon: Icons.lock,
                      color: VizColors.warning,
                      label: l10n.shareLocked,
                    ),
                  if (readOnly)
                    StatusLabel(
                      icon: Icons.visibility_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      label: l10n.shareReadOnly,
                    ),
                ],
              ),
            ),
        ],
      ),
      trailing: Semantics(
        label: l10n.shareEnabled,
        child: Switch.adaptive(value: enabled, onChanged: onToggle),
      ),
      onTap: onTap,
    );
  }
}

class NewShareRequest {
  const NewShareRequest({
    required this.path,
    required this.comment,
    required this.readOnly,
    this.name,
  });

  final String? name;
  final String path;
  final String comment;
  final bool readOnly;
}

/// Asks for a new share's folder, description, and (for SMB) name.
/// NFS also gets a read-only switch.
class NewShareDialog extends StatefulWidget {
  const NewShareDialog({
    super.key,
    required this.paths,
    required this.withName,
  });

  final List<String> paths;

  /// SMB shares have a name; NFS exports are named by their path.
  final bool withName;

  @override
  State<NewShareDialog> createState() => _NewShareDialogState();
}

class _NewShareDialogState extends State<NewShareDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _comment = TextEditingController();
  late String? _path = widget.paths.firstOrNull;
  bool _nameEdited = false;
  bool _readOnly = false;

  @override
  void initState() {
    super.initState();
    _suggestName();
  }

  @override
  void dispose() {
    _name.dispose();
    _comment.dispose();
    super.dispose();
  }

  /// Uses the folder's last component as the share name until edited.
  void _suggestName() {
    final path = _path;
    if (!_nameEdited && path != null) _name.text = path.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final path = _path;
    return AlertDialog(
      title: Text(l10n.shareCreate),
      content: path == null
          ? Text(l10n.shareNoDatasets)
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SharePathField(
                      paths: widget.paths,
                      value: path,
                      onChanged: (p) => setState(() {
                        _path = p;
                        _suggestName();
                      }),
                    ),
                    if (widget.withName) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const Key('shareName'),
                        controller: _name,
                        autocorrect: false,
                        decoration: InputDecoration(labelText: l10n.shareName),
                        onChanged: (_) => _nameEdited = true,
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? l10n.validationRequired
                            : null,
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _comment,
                      decoration: InputDecoration(labelText: l10n.shareComment),
                    ),
                    if (!widget.withName)
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.shareReadOnly),
                        value: _readOnly,
                        onChanged: (v) => setState(() => _readOnly = v),
                      ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(path == null ? l10n.close : l10n.cancel),
        ),
        if (path != null)
          FilledButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                NewShareRequest(
                  name: widget.withName ? _name.text.trim() : null,
                  path: path,
                  comment: _comment.text.trim(),
                  readOnly: _readOnly,
                ),
              );
            },
            child: Text(l10n.create),
          ),
      ],
    );
  }
}

class ShareEditResult {
  const ShareEditResult({
    required this.comment,
    required this.enabled,
    required this.readOnly,
    this.browsable,
    this.delete = false,
  });

  const ShareEditResult.delete()
    : comment = '',
      enabled = false,
      readOnly = false,
      browsable = null,
      delete = true;

  final String comment;
  final bool enabled;
  final bool readOnly;

  /// SMB only.
  final bool? browsable;
  final bool delete;
}

/// Edits the settings both SMB and NFS shares have; [browsable] is shown
/// only when given (SMB).
class ShareEditDialog extends StatefulWidget {
  const ShareEditDialog({
    super.key,
    required this.title,
    required this.comment,
    required this.enabled,
    required this.readOnly,
    this.browsable,
  });

  final String title;
  final String comment;
  final bool enabled;
  final bool readOnly;
  final bool? browsable;

  @override
  State<ShareEditDialog> createState() => _ShareEditDialogState();
}

class _ShareEditDialogState extends State<ShareEditDialog> {
  late final _comment = TextEditingController(text: widget.comment);
  late bool _enabled = widget.enabled;
  late bool _readOnly = widget.readOnly;
  late bool? _browsable = widget.browsable;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title, overflow: TextOverflow.ellipsis),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _comment,
              decoration: InputDecoration(labelText: l10n.shareComment),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.shareEnabled),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.shareReadOnly),
              value: _readOnly,
              onChanged: (v) => setState(() => _readOnly = v),
            ),
            if (_browsable != null)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.shareBrowsable),
                value: _browsable!,
                onChanged: (v) => setState(() => _browsable = v),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          onPressed: () =>
              Navigator.pop(context, const ShareEditResult.delete()),
          child: Text(l10n.shareDelete),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            ShareEditResult(
              comment: _comment.text.trim(),
              enabled: _enabled,
              readOnly: _readOnly,
              browsable: _browsable,
            ),
          ),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
