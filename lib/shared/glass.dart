import 'dart:math' as math;

import 'package:flutter/cupertino.dart'
    show showCupertinoDialog, showCupertinoModalPopup;
import 'package:flutter/foundation.dart'
    show ValueListenable, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lg;
import 'package:native_liquid_glass/native_liquid_glass.dart' as nlg;

import 'theme.dart';

// The one place that knows about liquid_glass_widgets and native_liquid_glass,
// so swapping them out touches this file only.

/// Height of the floating glass tab bar.
const _barHeight = 64.0;

/// Gap between the glass tab bar and the bottom safe area.
const _barGap = 12.0;

/// Whether the screen gets iOS 26 style glass chrome: a floating glass tab
/// bar and content scrolling under a blurred top edge.
bool useGlassChrome(BuildContext context) => isCupertino(context);

/// Whether the tab bar, switch, slider and segmented control are Apple's own
/// UIKit views (iOS 26 and later, hosted as platform views) rather than the
/// package's shader look-alikes. Only the system material follows what the
/// user chose in Settings (Reduce Transparency, and the iOS 27 glass look).
/// Never true in tests, which do not run on an iPhone.
bool useNativeGlass(BuildContext context) =>
    useGlassChrome(context) && nlg.NativeLiquidGlassUtils.supportsLiquidGlass;

/// Fades native glass out under dialogs, sheets and other pop-up routes, which
/// it would otherwise bleed through (a native view sits above Flutter's
/// surface), and pauses it for the whole of a page transition, a drag back
/// included (the native views do not follow a page that is moving). Add it to
/// the app's `navigatorObservers`.
NavigatorObserver glassNavigatorObserver() => _GlassObserver();

class _GlassObserver extends nlg.LiquidGlassNavigatorObserver {
  VoidCallback? _release;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _pauseWhileMoving(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _pauseWhileMoving(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _pauseWhileMoving(newRoute);
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    _release ??= pauseNativeGlass();
  }

  @override
  void didStopUserGesture() {
    _release?.call();
    _release = null;
  }

  /// Pauses native glass until [route]'s transition animation has ended. Pop-up
  /// routes are left to the package, which fades the views under them.
  void _pauseWhileMoving(Route<dynamic>? route) {
    if (route is! TransitionRoute || route is PopupRoute) return;
    final animation = route.animation;
    if (animation == null || animation.isCompleted || animation.isDismissed) {
      return;
    }
    final release = pauseNativeGlass();
    late final AnimationStatusListener onStatus;
    onStatus = (status) {
      if (!status.isCompleted && !status.isDismissed) return;
      // A route is built once, offstage and at the end of its animation, to
      // measure heroes; it then reports completed without having moved.
      if (route is ModalRoute && route.offstage) return;
      animation.removeStatusListener(onStatus);
      release();
    };
    animation.addStatusListener(onStatus);
  }
}

// How many reasons there are to draw the Flutter look-alikes instead of the
// native views right now (see [pauseNativeGlass]).
final _pauses = ValueNotifier<int>(0);

/// How many [pauseNativeGlass] calls are in force.
@visibleForTesting
int get nativeGlassPauses => _pauses.value;

/// Forgets every pause, for a test that ended mid-transition.
@visibleForTesting
void resetNativeGlassPauses() => _pauses.value = 0;

/// Draws the Flutter look-alikes of the switch, slider and segments in place of
/// the native views (and hides the tab bar, whose look-alike would flip to the
/// native bar when this ends) until the returned callback is called. A native
/// view is a real UIView above Flutter's surface: it does not follow a page
/// that is moving and it shows through anything Flutter paints over it (the app
/// lock cover). Calls stack; the callback may be called more than once.
VoidCallback pauseNativeGlass() {
  _pauses.value++;
  var released = false;
  return () {
    if (released) return;
    released = true;
    _pauses.value--;
  };
}

/// Whether the soft keyboard is up. A native switch, slider or segmented control
/// trails the page while the keyboard moves it (and while the list scrolls
/// under it), so these use the Flutter look-alikes then. Not read from a
/// [MediaQuery]: a [Scaffold] removes the keyboard's insets from its body.
final _keyboardUp = _KeyboardWatcher();

class _KeyboardWatcher extends ValueNotifier<bool> with WidgetsBindingObserver {
  _KeyboardWatcher() : super(false) {
    WidgetsBinding.instance.addObserver(this);
    _update();
  }

  @override
  void didChangeMetrics() => _update();

  void _update() => value = WidgetsBinding.instance.platformDispatcher.views
      .any((view) => view.viewInsets.bottom > 0);
}

/// [native] on an iPhone with native glass, unless it is paused or the keyboard
/// is up; [fallback] otherwise.
Widget _nativeOrFallback(
  BuildContext context, {
  required Widget Function() native,
  required Widget Function() fallback,
}) {
  if (!useNativeGlass(context)) return fallback();
  final ValueListenable<bool> keyboard = _keyboardUp;
  return ListenableBuilder(
    listenable: Listenable.merge([_pauses, keyboard]),
    builder: (context, _) =>
        _pauses.value > 0 || keyboard.value ? fallback() : native(),
  );
}

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
    this.badges = const {},
  });

  /// Icon, selected icon and label per tab.
  final List<(IconData, IconData, String)> destinations;

  /// Count to show on a tab's icon, by tab index; none for zero or a tab left
  /// out. A plain [Badge] rather than the package's glass one, which would be
  /// glass inside the glass bar.
  final Map<int, int> badges;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => useNativeGlass(context)
      // Not the shader bar while paused: it would flip to the native one when
      // the page stops moving. The keyboard does not move this bar.
      ? ValueListenableBuilder<int>(
          valueListenable: _pauses,
          builder: (context, pauses, _) =>
              pauses > 0 ? const SizedBox.shrink() : _buildNative(context),
        )
      : _buildShader(context);

  double _width(BuildContext context) =>
      math.min(MediaQuery.sizeOf(context).width - 24, 440.0);

  Widget _buildNative(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    // A real UITabBar: iOS draws the glass, so it follows the system
    // settings. Only the selected tab takes the accent colour.
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        // The native view reserves 20 points of overflow for its glow and
        // sits that much higher than the shader bar, so it takes no gap of
        // its own: it then rests about where the shader bar did.
        child: Padding(
          padding: EdgeInsets.zero,
          child: nlg.LiquidGlassTabBar(
            width: _width(context),
            height: _barHeight,
            selectedItemColor: accent,
            currentIndex: selectedIndex,
            onTabSelected: onSelected,
            items: [
              for (final (i, (icon, selected, label)) in destinations.indexed)
                nlg.LiquidGlassTabItem(
                  label: label,
                  icon: _nativeIcon(icon, selected: false),
                  selectedIcon: _nativeIcon(selected, selected: true),
                  iosBadgeValue: (badges[i] ?? 0) > 0 ? '${badges[i]}' : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShader(BuildContext context) {
    final width = _width(context);
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
                  for (final (i, (icon, selected, label))
                      in destinations.indexed)
                    lg.GlassTab(
                      icon: _badged(Icon(icon), badges[i] ?? 0),
                      activeIcon: _badged(Icon(selected), badges[i] ?? 0),
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

/// The tab's icon as an SF Symbol, which UIKit draws at the right size. The
/// package turns a Flutter icon into a picture, and on a phone that came out
/// several times too big, so every tab icon needs an entry here (the Material
/// icon is the fallback, wrong size or not).
nlg.NativeLiquidGlassIcon _nativeIcon(IconData icon, {required bool selected}) {
  final name = switch (icon) {
    Icons.space_dashboard_outlined => 'square.grid.2x2',
    Icons.space_dashboard_rounded => 'square.grid.2x2.fill',
    Icons.storage_outlined => 'externaldrive',
    Icons.storage_rounded => 'externaldrive.fill',
    Icons.folder_shared_outlined => 'folder.badge.person.crop',
    Icons.folder_shared_rounded => 'folder.fill.badge.person.crop',
    Icons.widgets_outlined => 'square.stack.3d.up',
    Icons.widgets_rounded => 'square.stack.3d.up.fill',
    Icons.more_horiz_rounded => 'ellipsis',
    _ => null,
  };
  return name == null
      ? nlg.NativeLiquidGlassIcon.iconData(icon)
      : nlg.NativeLiquidGlassIcon.sfSymbol(name);
}

Widget _badged(Widget icon, int count) =>
    count > 0 ? Badge.count(count: count, child: icon) : icon;

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
  Widget build(BuildContext context) => _nativeOrFallback(
    context,
    native: () => nlg.LiquidGlassToggle(
      value: value,
      enabled: onChanged != null,
      height: 31,
      onChanged: onChanged ?? (_) {},
    ),
    fallback: () => Opacity(
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
  Widget build(BuildContext context) => _nativeOrFallback(
    context,
    native: () => nlg.LiquidGlassSlider(
      value: value.clamp(min, max),
      min: min,
      max: max,
      step: divisions == null ? null : (max - min) / divisions!,
      // The UISlider reports no end of drag, so [onChangeEnd] is not
      // called here.
      onChanged: onChanged,
    ),
    fallback: () => lg.GlassSlider(
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      useOwnLayer: true,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    ),
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
  Widget build(BuildContext context) => icons == null
      // The UISegmentedControl has no icons, so those keep the package's.
      ? _nativeOrFallback(
          context,
          native: () => nlg.LiquidGlassSegmentedControl(
            labels: labels,
            selectedIndex: selectedIndex,
            height: 36,
            onValueChanged: onSelected,
          ),
          // Same size as the native control, so swapping does not move
          // anything.
          fallback: () => _shaderSegments(36),
        )
      : _shaderSegments(58);

  Widget _shaderSegments(double height) => lg.GlassSegmentedControl(
    useOwnLayer: true,
    // Tall enough for an icon above its label (when there is one), and a
    // capsule like the system's.
    height: height,
    borderRadius: height / 2,
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
