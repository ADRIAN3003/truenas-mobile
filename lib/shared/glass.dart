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

/// An iOS 26 alert on liquid glass: an optional [icon], a centred [title],
/// scrolling [content], and [actions] ([GlassDialogButton]s), side by side
/// when there are two or fewer and stacked otherwise.
///
/// The glass is left plain: no tint, rim or button colours of our own, so it
/// looks like the system's.
class GlassDialogPanel extends StatelessWidget {
  const GlassDialogPanel({
    super.key,
    this.icon,
    this.title,
    this.content,
    this.actions = const [],
  });

  final Widget? icon;
  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final scheme = theme.colorScheme;
    return SafeArea(
      child: AnimatedPadding(
        // Keep the panel above the keyboard.
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
              child: lg.GlassCard(
                useOwnLayer: true,
                shape: const lg.LiquidRoundedSuperellipse(borderRadius: 34),
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
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
                      DefaultTextStyle(
                        style: text.titleMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                        child: title!,
                      ),
                    if (content != null)
                      Flexible(
                        child: Padding(
                          padding: EdgeInsets.only(top: title == null ? 0 : 10),
                          child: SingleChildScrollView(
                            child: DefaultTextStyle(
                              style: text.bodyMedium!.copyWith(
                                color: scheme.onSurface,
                              ),
                              child: content!,
                            ),
                          ),
                        ),
                      ),
                    if (actions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: actions.length <= 2
                            ? Row(
                                children: [
                                  for (final (i, action) in actions.indexed)
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.only(
                                          start: i == 0 ? 0 : 8,
                                        ),
                                        child: action,
                                      ),
                                    ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: 8,
                                children: actions,
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

/// A button of a [GlassDialogPanel]: a solid capsule with a text label, like
/// the buttons of the system's alerts. The main action ([primary]) is filled
/// with the accent colour; the rest are a neutral grey. A [destructive] label
/// is red. Nothing is see-through, so every button stands out on the glass.
class GlassDialogButton extends StatelessWidget {
  const GlassDialogButton({
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    // A destructive action is never filled: the label alone warns.
    final filled = primary && !destructive;
    final background = filled
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: dark ? 0.22 : 0.12);
    final foreground = filled
        ? scheme.onPrimary
        : destructive
        ? (dark ? const Color(0xFFFF6961) : const Color(0xFFE5271B))
        : scheme.onSurface;
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Material(
        color: background,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 46,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: primary ? FontWeight.w700 : FontWeight.w500,
                    color: foreground,
                  ),
                  child: IconTheme.merge(
                    data: IconThemeData(color: foreground, size: 18),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        if (icon != null) Icon(icon),
                        Flexible(
                          child: Text(
                            label,
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
