import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An icon in a status colour followed by a label in normal text colour.
class StatusLabel extends StatelessWidget {
  const StatusLabel({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}

class LegendItem extends StatelessWidget {
  const LegendItem(this.color, this.label, {super.key});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

/// A horizontal bar split into segments by fraction, with 2 px gaps.
class SegmentedBar extends StatelessWidget {
  const SegmentedBar({super.key, required this.segments});

  final List<(double, Color)> segments;

  @override
  Widget build(BuildContext context) {
    final visible = segments.where((s) => s.$1 > 0.002).toList();
    return SizedBox(
      height: 10,
      child: Row(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              flex: math.max((visible[i].$1 * 1000).round(), 1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: visible[i].$2,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Asks the user to confirm an action. With [typeToConfirm], the confirm
/// button only enables once that exact text is typed (for destructive
/// actions such as deleting a dataset).
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  String? typeToConfirm,
  String? typeToConfirmHint,
  bool destructive = false,
}) async {
  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final theme = Theme.of(context);
        final enabled =
            typeToConfirm == null || controller.text.trim() == typeToConfirm;
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body),
              if (typeToConfirm != null) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autocorrect: false,
                  decoration: InputDecoration(labelText: typeToConfirmHint),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    )
                  : null,
              onPressed: enabled ? () => Navigator.pop(context, true) : null,
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );
  controller.dispose();
  return confirmed ?? false;
}
