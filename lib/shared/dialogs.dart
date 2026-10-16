import 'package:flutter/material.dart';

import 'glass.dart';

/// Dialogs, sheets and menus that follow the platform: liquid glass on iOS
/// (like the system's own on iOS 26), Material elsewhere. Callers build the
/// same content for both.

/// An alert or form dialog: [AlertDialog] on Android, a liquid glass panel
/// on iOS.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.icon,
    this.title,
    this.content,
    this.actions = const [],
    this.scrollable = false,
  });

  final Widget? icon;
  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  /// Lets the content scroll when it is taller than the screen (a long list
  /// of choices). Always so on iOS.
  final bool scrollable;

  @override
  Widget build(BuildContext context) => useGlassChrome(context)
      ? GlassDialogPanel(
          icon: icon,
          title: title,
          content: content,
          actions: actions,
        )
      : AlertDialog(
          icon: icon,
          title: title,
          content: content,
          actions: actions,
          scrollable: scrollable,
        );
}

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

/// A bottom sheet: a modal sheet with a drag handle on Android, a floating
/// liquid glass sheet on iOS.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => useGlassChrome(context)
    ? showGlassSheet<T>(context: context, builder: builder)
    : showModalBottomSheet<T>(
        context: context,
        showDragHandle: true,
        builder: builder,
      );

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
