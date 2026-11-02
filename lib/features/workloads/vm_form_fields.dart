import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// A dropdown over [options] (value → label). A [value] the server no longer
/// lists is kept as an entry of its own, so opening an editor never changes
/// a setting by itself. A null entry labelled [noneLabel] is added when given.
Widget vmChoiceField({
  required String label,
  required String? value,
  required Map<String, String> options,
  required ValueChanged<String?> onChanged,
  String? noneLabel,
  String? helper,
}) {
  final shown = {
    if (value != null && !options.containsKey(value)) value: value,
    ...options,
  };
  return DropdownButtonFormField<String?>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label, helperText: helper),
    items: [
      if (noneLabel != null)
        DropdownMenuItem<String?>(value: null, child: Text(noneLabel)),
      for (final MapEntry(:key, :value) in shown.entries)
        DropdownMenuItem<String?>(
          value: key,
          child: Text(value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onChanged,
  );
}

/// A whole-number field that wants at least [min].
Widget vmNumberField(
  BuildContext context, {
  required TextEditingController controller,
  required String label,
  int min = 1,
  String? helper,
  bool optional = false,
}) {
  final l10n = AppLocalizations.of(context);
  return TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label, helperText: helper),
    validator: (v) {
      final text = (v ?? '').trim();
      if (optional && text.isEmpty) return null;
      return (int.tryParse(text) ?? min - 1) < min
          ? l10n.explorerInvalidNumber
          : null;
    },
  );
}

/// A required text field.
Widget vmTextField(
  BuildContext context, {
  required TextEditingController controller,
  required String label,
  bool required = true,
  String? helper,
  bool obscure = false,
  Widget? suffix,
}) {
  final l10n = AppLocalizations.of(context);
  return TextFormField(
    controller: controller,
    autocorrect: false,
    obscureText: obscure,
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 3,
      suffixIcon: suffix,
    ),
    validator: required
        ? (v) => (v ?? '').trim().isEmpty ? l10n.validationRequired : null
        : null,
  );
}

/// The name of a new zvol for [vm]'s disk number [index] in [pool], e.g.
/// `tank/win11-disk0`.
String newZvolName(String pool, String vm, int index) {
  final safe = vm.trim().replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '-');
  return '$pool/${safe.isEmpty ? 'vm' : safe}-disk$index';
}

/// GiB as bytes.
int gibToBytes(int gib) => gib * 1024 * 1024 * 1024;
