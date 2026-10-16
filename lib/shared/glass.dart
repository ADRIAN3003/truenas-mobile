import 'dart:math' as math;

import 'package:flutter/cupertino.dart'
    show showCupertinoDialog, showCupertinoModalPopup;
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
    // The package's bar is a 24% white wash on any background, which reads as
    // a light grey slab on a dark theme. Tint it with the page colour instead,
    // so it is dark in the dark theme and light in the light one.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final settings = lg.LiquidGlassSettings(
      thickness: 30,
      blur: 3,
      chromaticAberration: 0.3,
      lightIntensity: dark ? 0.35 : 0.6,
      refractiveIndex: 1.59,
      saturation: 0.7,
      ambientStrength: dark ? 0.2 : 1,
      lightAngle: 0.75 * math.pi,
      glassColor: AppPalette.of(context).background.withValues(alpha: 0.6),
    );
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
                settings: settings,
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
  IconData? icon,
  VoidCallback? onPressed,
  bool primary,
  bool destructive,
});

/// The roundness of the alert and the sheets, like iOS 26's.
const _panelRadius = 34.0;

/// A panel of glass that is readable: the package's glass with the app's own
/// surface colour over most of it, so what scrolls beneath shows through only
/// as a hint.
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = _panelRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fill = AppPalette.of(context).card.withValues(alpha: 0.86);
    return lg.GlassCard(
      useOwnLayer: true,
      shape: lg.LiquidRoundedSuperellipse(borderRadius: radius),
      padding: EdgeInsets.zero,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: fill,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// An iOS 26 alert on the package's glass: an optional [icon], a centred
/// [title] and [message], scrolling [content] (a form, a list) and [actions]
/// as solid, fully rounded buttons, side by side when there are two or fewer
/// and stacked otherwise. It lifts above the keyboard.
///
/// The package's own [lg.GlassDialog] has fixed, see-through buttons and a
/// corner radius that cannot be changed, which did not stand out or look like
/// the system's alerts on a device, so the panel is built here from its glass.
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
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;
    final buttons = [
      for (final action in actions) _AlertButton(action: action),
    ];
    return SafeArea(
      child: AnimatedPadding(
        // Keep the alert above the keyboard.
        padding:
            MediaQuery.viewInsetsOf(context) +
            const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        duration: const Duration(milliseconds: 100),
        curve: Curves.decelerate,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            // The Material widgets inside (text fields, list tiles) need a
            // Material ancestor, which a Cupertino route does not provide.
            child: Material(
              type: MaterialType.transparency,
              child: _GlassPanel(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (icon != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: IconTheme.merge(
                          data: const IconThemeData(size: 32),
                          child: Center(child: icon),
                        ),
                      ),
                    if (title != null)
                      Text(
                        title!,
                        textAlign: TextAlign.center,
                        style: text.titleLarge!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    if (message != null)
                      Padding(
                        padding: EdgeInsets.only(top: title == null ? 0 : 8),
                        child: Text(
                          message!,
                          textAlign: TextAlign.center,
                          style: text.bodyMedium!.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    if (content != null)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SingleChildScrollView(child: content),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: actions.length <= 2
                          ? Row(
                              spacing: 10,
                              children: [
                                for (final button in buttons)
                                  Expanded(child: button),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: 10,
                              children: buttons,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A button of a [GlassAlert]: a solid capsule with a text label, like the
/// system's alerts. The main action is filled with the accent colour, the
/// rest are a neutral grey, and a destructive label is red. Nothing is
/// see-through, so every button stands out on the glass.
class _AlertButton extends StatelessWidget {
  const _AlertButton({required this.action});

  final GlassAlertAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    // A destructive action is never filled: the label alone warns.
    final filled = action.primary && !action.destructive;
    final background = filled
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: dark ? 0.2 : 0.1);
    final foreground = filled
        ? scheme.onPrimary
        : action.destructive
        ? (dark ? const Color(0xFFFF6961) : const Color(0xFFE5271B))
        : scheme.onSurface;
    return Opacity(
      opacity: action.onPressed == null ? 0.4 : 1,
      child: Material(
        color: background,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action.onPressed,
          child: SizedBox(
            height: 50,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: action.primary
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: foreground,
                  ),
                  child: IconTheme.merge(
                    data: IconThemeData(color: foreground, size: 18),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        if (action.icon != null) Icon(action.icon),
                        Flexible(
                          child: Text(
                            action.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
}) => showCupertinoModalPopup<(T,)>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: 0.45),
  builder: (context) =>
      _ChoiceSheet<T>(title: title, choices: choices, cancelLabel: cancelLabel),
);

/// The sheet of [showGlassChoices]: a card of choices and a separate cancel
/// card, floating at the bottom like the system's.
class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.choices,
    required this.cancelLabel,
  });

  final String? title;
  final List<GlassChoice<T>> choices;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final divider = Divider(
      height: 0.5,
      thickness: 0.5,
      color: scheme.onSurface.withValues(alpha: 0.15),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              Flexible(
                child: _GlassPanel(
                  radius: 28,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (title != null) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Text(
                                title!,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ),
                            divider,
                          ],
                          for (final (i, choice) in choices.indexed) ...[
                            if (i > 0) divider,
                            _SheetRow(
                              label: choice.label,
                              leading: choice.selected
                                  ? const Icon(Icons.check_rounded)
                                  : choice.icon,
                              onTap: () =>
                                  Navigator.pop(context, (choice.value,)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _GlassPanel(
                radius: 28,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: _SheetRow(
                    label: cancelLabel,
                    bold: true,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.label,
    required this.onTap,
    this.leading,
    this.bold = false,
  });

  final String label;
  final Widget? leading;
  final bool bold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: IconTheme.merge(
          data: IconThemeData(color: scheme.onSurface, size: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
              ?leading,
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    // Tall enough for an icon above its label, and a capsule like the
    // system's.
    height: 58,
    borderRadius: 29,
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
