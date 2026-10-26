import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/models/app_catalog.dart';
import '../../core/models/app_values.dart';
import '../../l10n/generated/app_localizations.dart';
import 'app_form.dart';

/// What an app screen shares between installing and editing: the values being
/// edited, the form or the raw JSON view of them, and checking them before
/// they are sent.
mixin AppConfigState<W extends StatefulWidget> on State<W> {
  AppConfigSchema _schema = const AppConfigSchema();
  Map<String, dynamic> values = {};
  var _json = false;
  var _showProblems = false;
  var _revision = 0;
  final jsonController = TextEditingController();

  /// Whether the raw JSON is shown instead of the form.
  bool get jsonMode => _json;

  /// Whether the form can be drawn (there is a schema); without one the JSON
  /// is the only way, as for a custom app.
  bool get hasForm => _schema.questions.isNotEmpty;

  AppConfigSchema get schema => _schema;

  @override
  void dispose() {
    jsonController.dispose();
    super.dispose();
  }

  /// Starts editing [initial] (or the schema's defaults) against [schema].
  void startConfig(AppConfigSchema schema, [Map<String, dynamic>? initial]) {
    _schema = schema;
    values = AppValues.fill(
      schema.questions,
      initial == null ? {} : AppValues.copy(initial)! as Map<String, dynamic>,
    );
    _json = !hasForm;
    _revision++;
    if (_json) jsonController.text = _pretty(initial ?? values);
  }

  /// Moves to another version's form, keeping what was typed.
  void changeSchema(AppConfigSchema schema) {
    _schema = schema;
    values = AppValues.fill(schema.questions, values);
    _revision++;
    if (!hasForm) _json = true;
  }

  static String _pretty(Object? value) =>
      const JsonEncoder.withIndent('  ').convert(value);

  /// Switches between the form and the JSON. Leaving the JSON with text that
  /// isn't an object stays and says so.
  void toggleJson() {
    if (!_json) {
      jsonController.text = _pretty(AppValues.prune(_schema.questions, values));
      setState(() => _json = true);
      return;
    }
    final parsed = _parseJson();
    if (parsed == null) return;
    setState(() {
      values = AppValues.fill(_schema.questions, parsed);
      _revision++;
      _json = false;
    });
  }

  Map<String, dynamic>? _parseJson() {
    final l10n = AppLocalizations.of(context);
    try {
      final parsed = jsonDecode(jsonController.text);
      if (parsed is Map<String, dynamic>) return parsed;
      _say(l10n.appFormJsonObject);
    } on FormatException {
      _say(l10n.appFormJsonInvalid);
    }
    return null;
  }

  void _say(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  /// The values to send, or null when something is wrong (and said so).
  Map<String, dynamic>? collectValues() {
    if (_json) return _parseJson();
    final problem = AppValues.firstProblem(_schema.questions, values);
    if (problem != null) {
      setState(() => _showProblems = true);
      final l10n = AppLocalizations.of(context);
      _say('${problem.$1.label}: ${appValueProblem(l10n, problem.$2)}');
      return null;
    }
    return AppValues.prune(_schema.questions, values);
  }

  /// The form, or the JSON box, for the screen's list.
  Widget configBody({bool editing = false, String? jsonLabel}) {
    if (_json) {
      final l10n = AppLocalizations.of(context);
      return TextField(
        controller: jsonController,
        minLines: 8,
        maxLines: 30,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.multiline,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: InputDecoration(
          labelText: jsonLabel ?? l10n.appFormJsonLabel,
          alignLabelWithHint: true,
        ),
      );
    }
    return AppConfigForm(
      schema: _schema,
      values: values,
      editing: editing,
      showProblems: _showProblems,
      revision: _revision,
      onChanged: () => setState(() {}),
    );
  }

  /// The app bar button that flips between form and JSON, none when there is
  /// no form to go back to.
  Widget? jsonToggle() => hasForm
      ? IconButton(
          tooltip: _json
              ? AppLocalizations.of(context).appFormFields
              : AppLocalizations.of(context).appFormJson,
          icon: Icon(_json ? Icons.tune_rounded : Icons.data_object),
          onPressed: toggleJson,
        )
      : null;
}
