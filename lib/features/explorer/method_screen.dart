import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/api_method.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/viz_colors.dart';
import '../../shared/widgets.dart';
import '../../shared/connect_dialogs.dart';

const _pretty = JsonEncoder.withIndent('  ');

/// Results longer than this are cut in the view (copying gives all of it).
const _maxShown = 100000;

/// One method: its documentation, a form generated from its parameter
/// schemas, and the result of running it.
class MethodScreen extends StatefulWidget {
  const MethodScreen({super.key, required this.session, required this.method});

  final TrueNasSession session;
  final ApiMethod method;

  @override
  State<MethodScreen> createState() => _MethodScreenState();
}

class _MethodScreenState extends State<MethodScreen> {
  final _formKey = GlobalKey<FormState>();
  late final List<_ParamInput> _inputs = [
    for (final p in widget.method.params) _ParamInput(p),
  ];

  bool _running = false;
  int? _jobId;
  String? _result;
  String? _error;

  ApiMethod get _method => widget.method;

  @override
  void dispose() {
    for (final input in _inputs) {
      input.dispose();
    }
    super.dispose();
  }

  /// Positional params up to the last one that is required or ticked.
  /// Unticked optional params before it get their default.
  List<Object?> _params() {
    final last = _inputs.lastIndexWhere((i) => i.included);
    return [
      for (final input in _inputs.take(last + 1))
        input.included ? input.value() : input.param.defaultValue,
    ];
  }

  Future<void> _run() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    final params = _params();
    if (!_method.readOnly) {
      final confirmed = await confirmAction(
        context,
        title: l10n.explorerRunTitle(_method.name),
        body: l10n.explorerRunBody,
        confirmLabel: l10n.explorerRun,
        cancelLabel: l10n.cancel,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _running = true;
      _jobId = null;
      _result = null;
      _error = null;
    });
    try {
      final result = await widget.session.explorer.run(
        _method,
        params,
        onJobStarted: (id) {
          if (mounted) setState(() => _jobId = id);
        },
      );
      if (!mounted) return;
      setState(() => _result = _pretty.convert(result));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeConnectError(l10n, error));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final transfersFile = _method.downloadable || _method.uploadable;
    final result = _result;
    final error = _error;
    final jobId = _jobId;
    return Scaffold(
      appBar: AppBar(title: Text(_method.name)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (_method.job)
                  Chip(
                    avatar: const Icon(Icons.work_history_outlined, size: 18),
                    label: Text(l10n.explorerJob),
                  ),
                if (_method.readOnly)
                  Chip(
                    avatar: const Icon(Icons.visibility_outlined, size: 18),
                    label: Text(l10n.explorerReadOnly),
                  ),
                if (_method.noAuthRequired)
                  Chip(label: Text(l10n.explorerNoAuth)),
              ],
            ),
            if (_method.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(_method.description),
            ],
            if (_method.roles.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.explorerRoles(_method.roles.join(', ')),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Text(l10n.explorerParameters, style: theme.textTheme.titleMedium),
            if (_inputs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.explorerNoParameters),
              ),
            for (final input in _inputs)
              _ParamField(input: input, onChanged: () => setState(() {})),
            const SizedBox(height: 16),
            if (transfersFile)
              Text(
                l10n.explorerFileTransfer,
                style: TextStyle(color: theme.colorScheme.error),
              )
            else
              FilledButton.icon(
                onPressed: _running ? null : _run,
                icon: _running
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(l10n.explorerRun),
              ),
            if (_running && jobId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.explorerJobRunning(jobId)),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: StatusLabel(
                  icon: Icons.error_outline,
                  color: VizColors.critical,
                  label: error,
                ),
              ),
            if (result != null) ...[
              const SizedBox(height: 16),
              _JsonBlock(title: l10n.explorerResult, text: result),
            ],
            if (_method.returns case final returns?) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l10n.explorerReturns),
                children: [_JsonBlock(text: _pretty.convert(returns))],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Form state for one parameter.
class _ParamInput {
  _ParamInput(this.param) : included = param.required {
    final initial = param.initialValue;
    switch (param.kind) {
      case ParamKind.boolean:
        boolValue = initial == true;
      case ParamKind.choice:
        final index = param.choices.indexOf(initial);
        choice = index >= 0 ? index : (param.nullable ? null : 0);
      case ParamKind.json:
        text.text = _pretty.convert(initial);
      case ParamKind.string || ParamKind.integer || ParamKind.number:
        text.text = initial == null ? '' : initial.toString();
    }
  }

  final ApiParam param;
  final text = TextEditingController();
  bool included;
  bool boolValue = false;

  /// Index into [ApiParam.choices], or null for "not set".
  int? choice;

  /// The value to send; call after validation.
  Object? value() => switch (param.kind) {
    ParamKind.boolean => boolValue,
    ParamKind.choice => choice == null ? null : param.choices[choice!],
    ParamKind.json => jsonDecode(text.text),
    ParamKind.string => text.text.isEmpty && param.nullable ? null : text.text,
    ParamKind.integer =>
      text.text.trim().isEmpty ? null : int.parse(text.text.trim()),
    ParamKind.number =>
      text.text.trim().isEmpty ? null : num.parse(text.text.trim()),
  };

  void dispose() => text.dispose();
}

class _ParamField extends StatelessWidget {
  const _ParamField({required this.input, required this.onChanged});

  final _ParamInput input;
  final VoidCallback onChanged;

  String? _validate(AppLocalizations l10n, String? value) {
    if (!input.included) return null;
    final text = value ?? '';
    switch (input.param.kind) {
      case ParamKind.json:
        try {
          jsonDecode(text);
        } on FormatException catch (e) {
          return l10n.explorerInvalidJson(e.message);
        }
      case ParamKind.integer:
        if (text.trim().isEmpty && input.param.nullable) return null;
        if (int.tryParse(text.trim()) == null) {
          return l10n.explorerInvalidNumber;
        }
      case ParamKind.number:
        if (text.trim().isEmpty && input.param.nullable) return null;
        if (num.tryParse(text.trim()) == null) {
          return l10n.explorerInvalidNumber;
        }
      case ParamKind.string || ParamKind.boolean || ParamKind.choice:
        break;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final param = input.param;
    final label = param.required
        ? param.name
        : '${param.name} (${l10n.explorerOptional})';
    final Widget field = switch (param.kind) {
      ParamKind.boolean => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: input.boolValue,
        onChanged: input.included
            ? (v) {
                input.boolValue = v;
                onChanged();
              }
            : null,
      ),
      ParamKind.choice => DropdownButtonFormField<int?>(
        initialValue: input.choice,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          if (param.nullable)
            DropdownMenuItem(value: null, child: Text(l10n.explorerUnset)),
          for (final (i, c) in param.choices.indexed)
            DropdownMenuItem(value: i, child: Text(jsonEncode(c))),
        ],
        onChanged: input.included
            ? (v) {
                input.choice = v;
                onChanged();
              }
            : null,
      ),
      ParamKind.json => TextFormField(
        controller: input.text,
        enabled: input.included,
        minLines: 2,
        maxLines: 12,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
        validator: (v) => _validate(l10n, v),
      ),
      ParamKind.string ||
      ParamKind.integer ||
      ParamKind.number => TextFormField(
        controller: input.text,
        enabled: input.included,
        autocorrect: false,
        keyboardType: param.kind == ParamKind.string
            ? TextInputType.text
            : const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
        decoration: InputDecoration(labelText: label),
        validator: (v) => _validate(l10n, v),
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!param.required)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('${l10n.explorerSendParam} ${param.name}'),
              value: input.included,
              onChanged: (v) {
                input.included = v ?? false;
                onChanged();
              },
            ),
          field,
          if (param.description case final description?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(description, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// Monospace, selectable JSON with a copy button.
class _JsonBlock extends StatelessWidget {
  const _JsonBlock({required this.text, this.title});

  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final shown = text.length > _maxShown
        ? '${text.substring(0, _maxShown)}\n…'
        : text;
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title ?? '', style: theme.textTheme.titleSmall),
                ),
                IconButton(
                  tooltip: l10n.copy,
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: text));
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.explorerCopied)),
                    );
                  },
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                shown,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
