import 'dart:math' as math;

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
    final palette = AppPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final width = math.min(MediaQuery.sizeOf(context).width - 24, 440.0);
    final unselected = palette.text.withValues(alpha: 0.75);
    // Tab labels stay at their size, like the system tab bar; the capsule
    // has no room to grow.
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
                selectedIndex: selectedIndex,
                onTabSelected: onSelected,
                // A light frost in light mode, smoked glass in dark mode, so
                // the labels keep their contrast over any content.
                settings: lg.LiquidGlassSettings(
                  glassColor: dark
                      ? const Color(0x801A2333)
                      : const Color(0xB3FFFFFF),
                  blur: 8,
                  thickness: 24,
                ),
                indicatorColor: primary.withValues(alpha: dark ? 0.22 : 0.14),
                selectedIconColor: primary,
                selectedLabelColor: primary,
                unselectedIconColor: unselected,
                unselectedLabelColor: unselected,
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
