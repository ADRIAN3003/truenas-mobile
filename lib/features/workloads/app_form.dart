import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/app_catalog.dart';
import '../../core/models/app_values.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';

/// The text for a value that doesn't fit its setting.
String appValueProblem(AppLocalizations l10n, AppValueProblem problem) =>
    switch (problem) {
      AppValueProblem.required => l10n.validationRequired,
      AppValueProblem.notNumber => l10n.appFormNotNumber,
      AppValueProblem.tooSmall => l10n.appFormTooSmall,
      AppValueProblem.tooLarge => l10n.appFormTooLarge,
      AppValueProblem.tooShort => l10n.appFormTooShort,
      AppValueProblem.tooLong => l10n.appFormTooLong,
      AppValueProblem.invalidChars => l10n.appFormInvalidChars,
    };

/// What the fields share while the form is built.
class _FormContext {
  const _FormContext({
    required this.editing,
    required this.showProblems,
    required this.revision,
    required this.onChanged,
  });

  final bool editing;
  final bool showProblems;
  final int revision;
  final VoidCallback onChanged;
}

/// The settings of an app as a form, drawn from the catalog's own question
/// schema: sections, text, numbers, switches, lists and nested groups, with
/// the rules that show a setting only when another one has a value.
///
/// It edits [values] in place and calls [onChanged] after each change, so the
/// owner can rebuild it (a switch can show or hide other settings). Bump
/// [revision] when [values] was replaced from outside.
class AppConfigForm extends StatelessWidget {
  const AppConfigForm({
    super.key,
    required this.schema,
    required this.values,
    required this.onChanged,
    this.editing = false,
    this.showProblems = false,
    this.revision = 0,
  });

  final AppConfigSchema schema;
  final Map<String, dynamic> values;
  final VoidCallback onChanged;

  /// Editing an installed app: settings that can't change after install are
  /// shown but locked.
  final bool editing;

  /// Show what is wrong with each value, once a save was refused.
  final bool showProblems;
  final int revision;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ctx = _FormContext(
      editing: editing,
      showProblems: showProblems,
      revision: revision,
      onChanged: onChanged,
    );
    final shown = [
      for (final q in AppValues.applicable(schema.questions, values))
        if (!q.isHidden) q,
    ];
    if (shown.isEmpty) {
      return EmptyCard(l10n.appFormNoSettings);
    }
    // Sections in the schema's order, then any the schema forgot to list.
    final names = <String?>[
      null,
      for (final g in schema.groups) g.name,
      for (final q in shown) q.group,
    ].map((n) => (n ?? '').trim()).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final name in names)
          ..._section(
            context,
            name,
            schema.groups.where((g) => g.name.trim() == name).firstOrNull,
            [
              for (final q in shown)
                if ((q.group ?? '').trim() == name) q,
            ],
            ctx,
          ),
      ],
    );
  }

  List<Widget> _section(
    BuildContext context,
    String name,
    AppSchemaGroup? group,
    List<AppQuestion> questions,
    _FormContext ctx,
  ) {
    if (questions.isEmpty) return const [];
    final theme = Theme.of(context);
    final description = group?.description?.trim();
    return [
      if (name.isNotEmpty) SectionHeader(name) else const SizedBox(height: 8),
      if (description != null && description.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppPalette.of(context).muted,
            ),
          ),
        ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _fields(context, questions, values, name, ctx),
          ),
        ),
      ),
    ];
  }
}

/// The fields for [questions] (already filtered to what is shown), spaced.
List<Widget> _fields(
  BuildContext context,
  List<AppQuestion> questions,
  Map<String, dynamic> values,
  String path,
  _FormContext ctx,
) => [
  for (final (i, q) in questions.indexed) ...[
    if (i > 0) const SizedBox(height: 16),
    _field(context, q, values, '$path/${q.variable}', ctx),
  ],
];

/// The shown settings of one level: `show_if` and sub-questions applied.
List<AppQuestion> _shown(List<AppQuestion> questions, Map<String, dynamic> v) =>
    [
      for (final q in AppValues.applicable(questions, v))
        if (!q.isHidden) q,
    ];

Widget _field(
  BuildContext context,
  AppQuestion q,
  Map<String, dynamic> values,
  String path,
  _FormContext ctx,
) {
  final s = q.schema;
  switch (s.type) {
    case 'dict':
      final current = values[q.variable];
      final map = current is Map<String, dynamic>
          ? current
          : (values[q.variable] = AppValues.defaultFor(q))!
                as Map<String, dynamic>;
      return _Nested(
        title: q.label,
        description: q.description,
        children: _fields(context, _shown(s.attrs, map), map, path, ctx),
      );
    case 'list':
      return _listField(context, q, values, path, ctx);
    default:
      return _valueField(
        context,
        q,
        values[q.variable],
        (value) {
          values[q.variable] = value;
          ctx.onChanged();
        },
        path,
        ctx,
      );
  }
}

Widget _listField(
  BuildContext context,
  AppQuestion q,
  Map<String, dynamic> values,
  String path,
  _FormContext ctx,
) {
  final l10n = AppLocalizations.of(context);
  final item = q.schema.items.firstOrNull;
  final list = values[q.variable] is List
      ? values[q.variable] as List<dynamic>
      : (values[q.variable] = <Object?>[]) as List<dynamic>;
  final locked = ctx.editing && !q.schema.editable;
  return _Nested(
    title: q.label,
    description: q.description,
    trailing: item == null || locked
        ? null
        : IconButton(
            tooltip: l10n.appFormAdd,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              list.add(AppValues.newItem(q));
              ctx.onChanged();
            },
          ),
    children: [
      if (item != null)
        for (final (i, entry) in list.indexed)
          _Nested(
            key: ValueKey('$path/$i/${list.length}/${ctx.revision}'),
            title: '${item.label} ${i + 1}',
            trailing: locked
                ? null
                : IconButton(
                    tooltip: l10n.actionDelete,
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      list.removeAt(i);
                      ctx.onChanged();
                    },
                  ),
            children:
                item.schema.type == 'dict' && entry is Map<String, dynamic>
                ? _fields(
                    context,
                    _shown(item.schema.attrs, entry),
                    entry,
                    '$path/$i',
                    ctx,
                  )
                : [
                    _valueField(
                      context,
                      item,
                      entry,
                      (value) {
                        list[i] = value;
                        ctx.onChanged();
                      },
                      '$path/$i',
                      ctx,
                    ),
                  ],
          ),
    ],
  );
}

/// One setting that holds a single value.
Widget _valueField(
  BuildContext context,
  AppQuestion q,
  Object? value,
  ValueChanged<Object?> set,
  String path,
  _FormContext ctx,
) {
  final l10n = AppLocalizations.of(context);
  final s = q.schema;
  final enabled = !(ctx.editing && !s.editable);
  final problem = ctx.showProblems ? AppValues.check(q, value) : null;
  final error = problem == null ? null : appValueProblem(l10n, problem);
  final helper = [
    if (q.description != null && q.description!.isNotEmpty) q.description!,
    if (!enabled) l10n.appFormLocked,
  ].join('\n');

  if (s.type == 'boolean') {
    return AppSwitchTile(
      contentPadding: EdgeInsets.zero,
      title: Text(q.label),
      subtitle: helper.isEmpty ? null : Text(helper),
      value: value == true,
      onChanged: enabled ? set : null,
    );
  }

  if (s.choices.isNotEmpty) {
    final known = s.choices.any((c) => c.value == value);
    return DropdownButtonFormField<Object?>(
      key: ValueKey('$path/${ctx.revision}/$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: q.label,
        helperText: helper.isEmpty ? null : helper,
        helperMaxLines: 4,
        errorText: error,
      ),
      items: [
        for (final c in s.choices)
          DropdownMenuItem(value: c.value, child: Text(c.label)),
        if (!known && value != null)
          DropdownMenuItem(value: value, child: Text('$value')),
      ],
      onChanged: enabled ? set : null,
    );
  }

  final isNumber = s.type == 'int';
  return _TextValue(
    key: ValueKey('$path/${ctx.revision}'),
    label: q.label + (s.required ? ' *' : ''),
    helper: helper.isEmpty ? null : helper,
    error: error,
    value: value?.toString() ?? '',
    enabled: enabled,
    secret: s.secret,
    multiline: s.type == 'text',
    keyboardType: isNumber
        ? const TextInputType.numberWithOptions(signed: true)
        : switch (s.type) {
            'uri' || 'url' => TextInputType.url,
            _ => s.type == 'text' ? TextInputType.multiline : null,
          },
    inputFormatters: isNumber
        ? [FilteringTextInputFormatter.allow(RegExp(r'[-0-9]'))]
        : null,
    onChanged: (text) => set(
      isNumber
          ? int.tryParse(text) ?? (text.isEmpty ? null : text)
          : text.isEmpty && s.nullable
          ? null
          : text,
    ),
  );
}

/// A bordered block for a nested group or list entry.
class _Nested extends StatelessWidget {
  const _Nested({
    super.key,
    required this.title,
    required this.children,
    this.description,
    this.trailing,
  });

  final String title;
  final String? description;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppPalette.of(context).muted;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.outlineVariant, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (description != null && description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                description!,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          for (final child in children) ...[const SizedBox(height: 12), child],
        ],
      ),
    );
  }
}

/// A text box that follows its value: typing reports it, and a value changed
/// from outside (a removed list entry, replaced JSON) shows up in the box.
class _TextValue extends StatefulWidget {
  const _TextValue({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.error,
    this.enabled = true,
    this.secret = false,
    this.multiline = false,
    this.keyboardType,
    this.inputFormatters,
  });

  final String label;
  final String? helper;
  final String? error;
  final String value;
  final bool enabled;
  final bool secret;
  final bool multiline;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String> onChanged;

  @override
  State<_TextValue> createState() => _TextValueState();
}

class _TextValueState extends State<_TextValue> {
  late final _controller = TextEditingController(text: widget.value);
  late bool _hidden = widget.secret;

  @override
  void didUpdateWidget(_TextValue old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    enabled: widget.enabled,
    obscureText: _hidden,
    minLines: widget.multiline ? 3 : 1,
    maxLines: widget.multiline ? 8 : 1,
    keyboardType: widget.keyboardType,
    inputFormatters: widget.inputFormatters,
    autocorrect: false,
    enableSuggestions: !widget.secret,
    decoration: InputDecoration(
      labelText: widget.label,
      helperText: widget.helper,
      helperMaxLines: 4,
      errorText: widget.error,
      suffixIcon: widget.secret
          ? IconButton(
              icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _hidden = !_hidden),
            )
          : null,
    ),
    onChanged: widget.onChanged,
  );
}
