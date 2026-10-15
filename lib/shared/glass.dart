import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'theme.dart';

// The one place that knows about liquid_glass_easy, so swapping it out (or
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
    // Tab labels stay at their size, like the system tab bar; the capsule
    // has no room to grow.
    return MediaQuery.withNoTextScaling(
      child: LiquidGlassTabBar(
        width: width,
        height: _barHeight,
        itemPadding: 4,
        margin: const EdgeInsets.only(bottom: _barGap),
        selectedIndex: selectedIndex,
        onChanged: onSelected,
        style: LiquidGlassTabBar.defaultStyle.copyWith(
          // A light frost in light mode, smoked glass in dark mode, so the
          // labels keep their contrast over any content.
          color: dark ? const Color(0x801A2333) : const Color(0xB3FFFFFF),
          shadow: const LiquidGlassShadow(blur: 6, opacity: 0.18),
        ),
        itemStyle: LiquidGlassTabItemStyle(
          iconSize: 22,
          selectedColor: primary,
          unselectedColor: palette.text.withValues(alpha: 0.75),
        ),
        pillStyle: LiquidGlassTabPillStyle(
          mode: LiquidGlassPillMode.impellerOnly,
          animated: true,
          color: primary.withValues(alpha: dark ? 0.22 : 0.14),
        ),
        items: [
          for (final (icon, selected, label) in destinations)
            LiquidGlassTabBarItem(
              icon: icon,
              selectedIcon: selected,
              label: label,
            ),
        ],
      ),
    );
  }
}

/// A blurred band under the transparent top bar that keeps the title
/// legible over content scrolling beneath it.
///
/// [height] is the status bar plus the top bar; it is passed in because
/// inside a body that extends behind the app bar, the media padding
/// already counts the bar.
class GlassTopEdge extends StatelessWidget {
  const GlassTopEdge({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: height,
      // The clip keeps the backdrop blur inside the band.
      child: IgnorePointer(
        child: ClipRect(
          child: LiquidGlassScrollEdge(
            edge: LiquidGlassEdge.top,
            color: AppPalette.of(context).background.withValues(alpha: 0.85),
            blur: 8,
          ),
        ),
      ),
    );
  }
}

/// Compiles the glass shaders so the first glass frame isn't frosted.
Future<void> warmUpGlass() async {
  try {
    await LiquidGlassShaders.ensureLoaded();
  } catch (_) {
    // Without the shaders the lenses fall back to frosted glass.
  }
}
