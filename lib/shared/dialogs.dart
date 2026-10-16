import 'package:flutter/material.dart';

import 'glass.dart';

/// Dialogs, choices and menus that follow the platform: the liquid_glass_widgets
/// ones on iOS (like the system's own on iOS 26), Material elsewhere. Callers
/// build the same content for both.

/// An alert or form dialog: [AlertDialog] on Android, a [GlassAlert] (the
/// package's glass dialog) on iOS.
///
/// [message] is the short text under the title. On iOS the title is plain
/// text, [actions] come from [dialogAction] (one to three of them), and
/// [icon] sits above the content.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.icon,
    this.title,
    this.message,
    this.content,
    this.actions = const [],
    this.scrollable = false,
  });

  final Widget? icon;
  final Widget? title;
  final String? message;
  final Widget? content;
  final List<Widget> actions;

  /// Lets the content scroll when it is taller than the screen (a long list
  /// of choices). Always so on iOS.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    if (useGlassChrome(context)) {
      final buttons = actions.whereType<DialogActionButton>().toList();
      assert(
        buttons.length == actions.length && buttons.isNotEmpty,
        'An iOS dialog needs one to three dialogAction buttons.',
      );
      return GlassAlert(
        title: switch (title) {
          Text(:final data?) => data,
          _ => null,
        },
        message: message,
        icon: icon,
        content: content,
        actions: [
          for (final button in buttons)
            (
              label: button.label,
              onPressed: button.onPressed,
              primary: button.primary,
              destructive: button.destructive,
            ),
        ],
      );
    }
    return AlertDialog(
      icon: icon,
      title: title,
      content: message == null
          ? content
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(message!),
                if (content != null) ...[const SizedBox(height: 16), content!],
              ],
            ),
      actions: actions,
      scrollable: scrollable,
    );
  }
}

/// A dialog button: plain text on Android ([primary] filled, [destructive]
/// red). On iOS [AppDialog] reads its label and flags and draws the glass
/// dialog's own button, which has no icon and cannot be disabled, so a
/// button without a handler does nothing there.
class DialogActionButton extends StatelessWidget {
  const DialogActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.destructive = false,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Text(label);
    final graphic = icon == null ? null : Icon(icon);
    if (primary) {
      final style = destructive
          ? FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            )
          : null;
      return graphic == null
          ? FilledButton(style: style, onPressed: onPressed, child: text)
          : FilledButton.icon(
              style: style,
              onPressed: onPressed,
              icon: graphic,
              label: text,
            );
    }
    final style = destructive
        ? TextButton.styleFrom(foregroundColor: scheme.error)
        : null;
    return graphic == null
        ? TextButton(style: style, onPressed: onPressed, child: text)
        : TextButton.icon(
            style: style,
            onPressed: onPressed,
            icon: graphic,
            label: text,
          );
  }
}

/// A button for [AppDialog.actions].
Widget dialogAction(
  BuildContext context, {
  required String label,
  required VoidCallback? onPressed,
  IconData? icon,
  bool primary = false,
  bool destructive = false,
}) => DialogActionButton(
  label: label,
  onPressed: onPressed,
  icon: icon,
  primary: primary,
  destructive: destructive,
);

/// Shows an [AppDialog] (or anything else built by [builder]) with the
/// platform's transition and barrier.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => useGlassChrome(context)
    ? showGlassDialog<T>(
        context: context,
        builder: builder,
        barrierDismissible: barrierDismissible,
      )
    : showDialog<T>(
        context: context,
        builder: builder,
        barrierDismissible: barrierDismissible,
      );

/// One choice of [showAppChoice]: [leading] is its icon, [selected] marks the
/// current one.
typedef AppChoice<T> = ({
  T value,
  String label,
  Widget? leading,
  bool selected,
});

/// An [AppChoice] without an icon, not selected.
AppChoice<T> appChoice<T>(
  T value,
  String label, {
  Widget? leading,
  bool selected = false,
}) => (value: value, label: label, leading: leading, selected: selected);

/// Picks one of [choices]: an action sheet in glass on iOS, a bottom sheet on
/// Android (a dialog with [dialogOnAndroid], for a long list). The result is a
/// record so choosing a null value is told apart from dismissing, which gives
/// null.
Future<(T,)?> showAppChoice<T>({
  required BuildContext context,
  required List<AppChoice<T>> choices,
  String? title,
  bool dialogOnAndroid = false,
}) {
  final cancel = MaterialLocalizations.of(context).cancelButtonLabel;
  if (useGlassChrome(context)) {
    return showGlassChoices<T>(
      context: context,
      title: title,
      cancelLabel: cancel,
      choices: [
        for (final c in choices)
          (
            value: c.value,
            label: c.label,
            icon: c.leading,
            selected: c.selected,
          ),
      ],
    );
  }
  Widget tiles(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final c in choices)
        ListTile(
          dense: dialogOnAndroid,
          leading: c.leading,
          title: Text(c.label),
          trailing: c.selected
              ? Icon(
                  Icons.check_rounded,
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,
          onTap: () => Navigator.pop(context, (c.value,)),
        ),
    ],
  );
  return dialogOnAndroid
      ? showDialog<(T,)>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: title == null ? null : Text(title),
            content: tiles(context),
          ),
        )
      : showModalBottomSheet<(T,)>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(child: tiles(context)),
        );
}

/// One entry of an [AppPopupMenu].
typedef AppMenuEntry<T> = ({T value, String label, bool destructive});

/// An entry for an [AppPopupMenu]. [destructive] entries are red on iOS.
AppMenuEntry<T> menuEntry<T>(
  T value,
  String label, {
  bool destructive = false,
}) => (value: value, label: label, destructive: destructive);

/// A "more" menu: [PopupMenuButton] on Android, a morphing liquid glass menu
/// on iOS.
class AppPopupMenu<T> extends StatelessWidget {
  const AppPopupMenu({
    super.key,
    required this.entries,
    required this.onSelected,
    this.enabled = true,
  });

  final List<AppMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) => useGlassChrome(context)
      ? GlassPopupMenu<T>(
          entries: entries,
          onSelected: onSelected,
          enabled: enabled,
        )
      : PopupMenuButton<T>(
          enabled: enabled,
          onSelected: onSelected,
          itemBuilder: (_) => [
            for (final entry in entries)
              PopupMenuItem(value: entry.value, child: Text(entry.label)),
          ],
        );
}
