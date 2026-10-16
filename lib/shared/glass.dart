import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show showCupertinoDialog;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lg;

import 'theme.dart';

// The one place that knows about liquid_glass_widgets, so swapping it out (or
// for Apple's own material later) touches this file only.

/// Height of the floating glass tab bar.
const _barHeight = 64.0;

/// Gap between the glass tab bar and the bottom safe area.
const _barGap = 12.0;

/// Whether the screen gets iOS 26 style glass chrome: a floating glass tab
/// bar and content scrolling under a blurred top edge.
bool useGlassChrome(BuildContext context) => isCupertino(context);

/// Space that floating chrome covers at the top and bottom of a tab, so its
/// list can start below the top bar and scroll clear of the tab bar.
class ChromeInsets extends InheritedWidget {
  const ChromeInsets({super.key, required this.insets, required super.child});

  final EdgeInsets insets;

  static EdgeInsets of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChromeInsets>()?.insets ??
      EdgeInsets.zero;

  /// [base] list padding plus the floating chrome's space.
  static EdgeInsets pad(BuildContext context, EdgeInsets base) =>
      base + of(context);

  @override
  bool updateShouldNotify(ChromeInsets old) => old.insets != insets;
}

/// Top and bottom space the glass chrome takes on this screen. Call it
/// outside the scaffold body, where the media padding is the device's.
EdgeInsets glassChromeInsets(BuildContext context) {
  final padding = MediaQuery.paddingOf(context);
  return EdgeInsets.only(
    top: padding.top + kToolbarHeight + 8,
    bottom: padding.bottom + _barHeight + _barGap + 8,
  );
}

/// The page's tabs on a floating liquid glass capsule. Place it as the last
/// child of a full-screen [Stack]; it positions itself.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// Icon, selected icon and label per tab.
  final List<(IconData, IconData, String)> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width - 24, 440.0);
    final accent = Theme.of(context).colorScheme.primary;
    // The glass itself stays plain; only the selected tab's icon and label
    // take the accent colour. A selected tab is drawn a second time on top of
    // the bar, 15% larger and heavier by default, and where that copy was
    // wider than the one beneath it the label looked half coloured (the "D" of
    // Dashboard). So the copy keeps the size and weight of the rest. Tab
    // labels stay at their size, like the system tab bar; the capsule has no
    // room to grow.
    const weight = TextStyle(fontWeight: FontWeight.w500);
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: _barGap),
          child: SizedBox(
            width: width,
            child: MediaQuery.withNoTextScaling(
              child: lg.GlassTabBar.bottom(
                barHeight: _barHeight,
                horizontalPadding: 0,
                verticalPadding: 0,
                iconSize: 22,
                magnification: 1,
                selectedIconColor: accent,
                selectedLabelColor: accent,
                selectedLabelStyle: weight,
                unselectedLabelStyle: weight,
                selectedIndex: selectedIndex,
                onTabSelected: onSelected,
                tabs: [
                  for (final (icon, selected, label) in destinations)
                    lg.GlassTab(
                      icon: Icon(icon),
                      activeIcon: Icon(selected),
                      label: label,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A progressively blurred band under the transparent top bar that keeps the
/// title legible over content scrolling beneath it.
///
/// [height] is the status bar plus the top bar; it is passed in because
/// inside a body that extends behind the app bar, the media padding
/// already counts the bar.
class GlassTopEdge extends StatelessWidget {
  const GlassTopEdge({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final background = AppPalette.of(context).background;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: height,
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const lg.ProgressiveBlur(maxSigma: 12),
            // A tint that fades out downwards, like the system bar's edge.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    background.withValues(alpha: 0.85),
                    background.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loads the glass shaders so the first glass frame isn't blank.
Future<void> warmUpGlass() async {
  try {
    await lg.LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
  } catch (_) {
    // Without the shaders the glass falls back to a plain frosted look.
  }
}

/// Wraps the app so glass follows the app's light or dark theme rather than
/// the system's, and honours Reduce Motion and Increase Contrast.
Widget wrapForGlass(Widget app) => lg.LiquidGlassWidgets.wrap(
  child: app,
  brightnessResolver: Theme.maybeBrightnessOf,
);

/// Shows [builder]'s dialog the way iOS does: a dimmed barrier and a panel
/// that scales in.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showCupertinoDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  builder: builder,
);

/// A button of a [GlassAlert].
typedef GlassAlertAction = ({
  String label,
  VoidCallback? onPressed,
  bool primary,
  bool destructive,
});

/// An iOS 26 alert: the package's [lg.GlassDialog] with a [title], a
/// [message], optional [content] (a form, a list; it scrolls when it is taller
/// than the room there is) and one to three [actions].
///
/// The package's dialog does not lift above the keyboard or scroll, and its
/// buttons cannot be disabled or carry an icon, so this wraps it for the first
/// two; an action without a handler does nothing.
class GlassAlert extends StatelessWidget {
  const GlassAlert({
    super.key,
    this.title,
    this.message,
    this.icon,
    this.content,
    required this.actions,
  });

  final String? title;
  final String? message;
  final Widget? icon;
  final Widget? content;
  final List<GlassAlertAction> actions;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // What is left for the content after the keyboard, the safe areas, the
    // margin, and the title, message and buttons around it.
    final room =
        media.size.height -
        media.viewInsets.bottom -
        media.padding.vertical -
        48 -
        170 -
        (message == null ? 0 : 90);
    final body = icon == null && content == null
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: IconTheme.merge(
                    data: const IconThemeData(size: 32),
                    child: Center(child: icon),
                  ),
                ),
              if (content != null)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: math.max(96, room)),
                  child: SingleChildScrollView(child: content),
                ),
            ],
          );
    return SafeArea(
      child: AnimatedPadding(
        // Keep the alert above the keyboard.
        padding: media.viewInsets + const EdgeInsets.all(24),
        duration: const Duration(milliseconds: 100),
        curve: Curves.decelerate,
        // The Material widgets inside (text fields, list tiles) need a
        // Material ancestor, which a Cupertino route does not provide.
        child: Material(
          type: MaterialType.transparency,
          child: lg.GlassDialog(
            title: title,
            message: message,
            content: body,
            maxWidth: 340,
            actions: [
              for (final action in actions)
                lg.GlassDialogAction(
                  label: action.label,
                  isPrimary: action.primary,
                  isDestructive: action.destructive,
                  onPressed: action.onPressed ?? () {},
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One choice of [showGlassChoices].
typedef GlassChoice<T> = ({T value, String label, Widget? icon, bool selected});

/// An iOS 26 action sheet that picks one of [choices] ([selected] is marked
/// with a check, otherwise the choice's [icon] shows). The result is a record
/// so choosing a null value is told apart from dismissing the sheet, which
/// gives null.
Future<(T,)?> showGlassChoices<T>({
  required BuildContext context,
  required List<GlassChoice<T>> choices,
  required String cancelLabel,
  String? title,
}) async {
  (T,)? picked;
  await lg.showGlassActionSheet<void>(
    context: context,
    title: title,
    cancelLabel: cancelLabel,
    actions: [
      for (final choice in choices)
        lg.GlassActionSheetAction(
          label: choice.label,
          icon: choice.selected ? const Icon(Icons.check_rounded) : choice.icon,
          // The sheet closes itself after this.
          onPressed: () => picked = (choice.value,),
        ),
    ],
  );
  return picked;
}

/// An iOS 26 switch: the package's [lg.GlassSwitch] on its own glass layer.
class GlassSwitchControl extends StatelessWidget {
  const GlassSwitchControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onChanged == null ? 0.4 : 1,
    child: IgnorePointer(
      ignoring: onChanged == null,
      child: lg.GlassSwitch(
        value: value,
        useOwnLayer: true,
        // Haptics follow the app's own setting (see Haptics).
        enableHaptics: false,
        onChanged: onChanged ?? (_) {},
      ),
    ),
  );
}

/// An iOS 26 slider: the package's [lg.GlassSlider] on its own glass layer.
class GlassSliderControl extends StatelessWidget {
  const GlassSliderControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.divisions,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;

  @override
  Widget build(BuildContext context) => lg.GlassSlider(
    value: value,
    min: min,
    max: max,
    divisions: divisions,
    useOwnLayer: true,
    onChanged: onChanged,
    onChangeEnd: onChangeEnd,
  );
}

/// An iOS 26 segmented control: the package's [lg.GlassSegmentedControl].
/// Not for use inside a glass dialog, where glass over glass distorts.
class GlassSegments extends StatelessWidget {
  const GlassSegments({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.icons,
  });

  final List<String> labels;
  final List<IconData>? icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => lg.GlassSegmentedControl(
    useOwnLayer: true,
    selectedIndex: selectedIndex,
    onSegmentSelected: onSelected,
    segments: [
      for (final (i, label) in labels.indexed)
        lg.GlassSegment(
          label: label,
          icon: icons == null ? null : Icon(icons![i], size: 18),
        ),
    ],
  );
}

/// One entry of a [GlassPopupMenu].
typedef GlassMenuEntry<T> = ({T value, String label, bool destructive});

/// An iOS 26 pull-down menu: the trigger morphs into a liquid glass list.
class GlassPopupMenu<T> extends StatelessWidget {
  const GlassPopupMenu({
    super.key,
    required this.entries,
    required this.onSelected,
    this.enabled = true,
    this.tooltip,
  });

  final List<GlassMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final bool enabled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => lg.GlassMenu(
    menuWidth: 220,
    autoAdjustToScreen: true,
    menuPadding: const EdgeInsets.all(12),
    triggerBuilder: (context, toggle) => IconButton(
      tooltip: tooltip ?? MaterialLocalizations.of(context).showMenuTooltip,
      onPressed: enabled ? toggle : null,
      icon: const Icon(Icons.more_horiz_rounded),
    ),
    items: [
      for (final entry in entries)
        lg.GlassMenuItem(
          title: entry.label,
          isDestructive: entry.destructive,
          onTap: () => onSelected(entry.value),
        ),
    ],
  );
}
