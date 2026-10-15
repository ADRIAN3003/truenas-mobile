import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The app's colours beyond the Material colour scheme: page and card
/// surfaces, hairlines, status tones and the icon tile hues.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.card,
    required this.cardRaised,
    required this.border,
    required this.text,
    required this.muted,
    required this.good,
    required this.goodSoft,
    required this.warning,
    required this.warningSoft,
    required this.critical,
    required this.criticalSoft,
    required this.info,
    required this.infoSoft,
    required this.heroStart,
    required this.heroEnd,
  });

  static const light = AppPalette(
    background: Color(0xFFF3F5F9),
    card: Color(0xFFFFFFFF),
    cardRaised: Color(0xFFF7F9FC),
    border: Color(0xFFE2E7EF),
    text: Color(0xFF0E1726),
    muted: Color(0xFF5C687A),
    good: Color(0xFF168A3E),
    goodSoft: Color(0xFFE3F5EA),
    warning: Color(0xFFB26A00),
    warningSoft: Color(0xFFFFF1D9),
    critical: Color(0xFFC9302C),
    criticalSoft: Color(0xFFFDE6E5),
    info: Color(0xFF0A6FC2),
    infoSoft: Color(0xFFE2F0FC),
    heroStart: Color(0xFF0B3D6B),
    heroEnd: Color(0xFF0A78C8),
  );

  static const dark = AppPalette(
    background: Color(0xFF0A101C),
    card: Color(0xFF121A29),
    cardRaised: Color(0xFF182234),
    border: Color(0xFF223049),
    text: Color(0xFFE7ECF4),
    muted: Color(0xFF94A2B8),
    good: Color(0xFF3FCB72),
    goodSoft: Color(0xFF12301F),
    warning: Color(0xFFF5B342),
    warningSoft: Color(0xFF392A0F),
    critical: Color(0xFFFF6B63),
    criticalSoft: Color(0xFF3E1717),
    info: Color(0xFF4DB5F5),
    infoSoft: Color(0xFF11304A),
    heroStart: Color(0xFF0F2A4A),
    heroEnd: Color(0xFF0D5A96),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? light;

  final Color background;
  final Color card;
  final Color cardRaised;
  final Color border;
  final Color text;
  final Color muted;
  final Color good;
  final Color goodSoft;
  final Color warning;
  final Color warningSoft;
  final Color critical;
  final Color criticalSoft;
  final Color info;
  final Color infoSoft;

  /// The server header gradient.
  final Color heroStart;
  final Color heroEnd;

  /// Solid icon tile hues, like the coloured squares in iOS Settings.
  static const tileBlue = Color(0xFF1C7FE0);
  static const tileTeal = Color(0xFF0E9C94);
  static const tileGreen = Color(0xFF2E9F4E);
  static const tileOrange = Color(0xFFE77B22);
  static const tilePurple = Color(0xFF7A5AE0);
  static const tileRed = Color(0xFFE0483E);
  static const tileSlate = Color(0xFF5D6B82);

  (Color, Color) tone(StatusTone tone) => switch (tone) {
    StatusTone.good => (good, goodSoft),
    StatusTone.warning => (warning, warningSoft),
    StatusTone.critical => (critical, criticalSoft),
    StatusTone.info => (info, infoSoft),
    StatusTone.neutral => (muted, cardRaised),
  };

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

enum StatusTone { good, warning, critical, info, neutral }

/// Whether the platform should get iOS behaviour (dialogs, switches,
/// chevrons, no ink splashes).
bool isCupertino(BuildContext context) => switch (Theme.of(context).platform) {
  TargetPlatform.iOS || TargetPlatform.macOS => true,
  _ => false,
};

/// Builds the light or dark app theme.
ThemeData buildAppTheme(
  Brightness brightness, {
  TargetPlatform? platform,
  List<String>? fontFamilyFallback,
}) {
  final dark = brightness == Brightness.dark;
  final p = dark ? AppPalette.dark : AppPalette.light;
  final primary = dark ? const Color(0xFF4DB5F5) : const Color(0xFF0A6FC2);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: dark ? const Color(0xFF03213A) : Colors.white,
    primaryContainer: p.infoSoft,
    onPrimaryContainer: dark
        ? const Color(0xFFCDE8FB)
        : const Color(0xFF07406F),
    secondary: dark ? const Color(0xFF41D1C4) : const Color(0xFF0E8C85),
    onSecondary: dark ? const Color(0xFF00201E) : Colors.white,
    secondaryContainer: dark
        ? const Color(0xFF0F3533)
        : const Color(0xFFDDF4F1),
    onSecondaryContainer: dark
        ? const Color(0xFFBDEFEA)
        : const Color(0xFF07403C),
    tertiary: dark ? const Color(0xFFB9A4FF) : const Color(0xFF6A4CD6),
    onTertiary: dark ? const Color(0xFF1E1147) : Colors.white,
    error: p.critical,
    onError: dark ? const Color(0xFF3B0907) : Colors.white,
    errorContainer: p.criticalSoft,
    onErrorContainer: dark ? const Color(0xFFFFD6D3) : const Color(0xFF6E1512),
    surface: p.card,
    onSurface: p.text,
    onSurfaceVariant: p.muted,
    surfaceContainerLowest: p.card,
    surfaceContainerLow: p.card,
    surfaceContainer: p.cardRaised,
    surfaceContainerHigh: p.cardRaised,
    surfaceContainerHighest: dark
        ? const Color(0xFF1E2A40)
        : const Color(0xFFEBEFF5),
    outline: dark ? const Color(0xFF3A4A66) : const Color(0xFFB8C2D1),
    outlineVariant: p.border,
    inverseSurface: dark ? const Color(0xFFE7ECF4) : const Color(0xFF1A2333),
    onInverseSurface: dark ? const Color(0xFF121A29) : const Color(0xFFF3F5F9),
    inversePrimary: dark ? const Color(0xFF0A6FC2) : const Color(0xFF4DB5F5),
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    platform: platform,
    fontFamilyFallback: fontFamilyFallback,
  );
  final cupertino = switch (base.platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };
  final text = _tune(base.textTheme, p);
  final radius12 = BorderRadius.circular(12);
  final buttonShape = RoundedRectangleBorder(borderRadius: radius12);

  return base.copyWith(
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    textTheme: text,
    extensions: [p],
    splashFactory: cupertino ? NoSplash.splashFactory : base.splashFactory,
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.border),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.muted,
      titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      subtitleTextStyle: text.bodyMedium?.copyWith(color: p.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: p.infoSoft,
      indicatorShape: RoundedRectangleBorder(borderRadius: radius12),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? primary : p.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelMedium?.copyWith(
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? primary : p.muted,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: p.card,
      indicatorColor: p.infoSoft,
      indicatorShape: RoundedRectangleBorder(borderRadius: radius12),
      selectedIconTheme: IconThemeData(color: primary),
      unselectedIconTheme: IconThemeData(color: p.muted),
      selectedLabelTextStyle: text.labelMedium?.copyWith(
        color: primary,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: text.labelMedium?.copyWith(color: p.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: radius12,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius12,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius12,
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius12,
        borderSide: BorderSide(color: p.critical),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: buttonShape,
        minimumSize: const Size(64, 46),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: buttonShape,
        minimumSize: const Size(64, 46),
        side: BorderSide(color: scheme.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: buttonShape),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.card,
      side: BorderSide(color: p.border),
      shape: const StadiumBorder(),
      labelStyle: text.labelLarge,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius12,
        side: BorderSide(color: p.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius12),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      primaryColor: primary,
      brightness: brightness,
    ),
  );
}

/// Tighter headings, no extra letter spacing on body text and tabular
/// numbers everywhere so live values don't jitter.
TextTheme _tune(TextTheme t, AppPalette p) {
  const tabular = [FontFeature.tabularFigures()];
  TextStyle? heading(TextStyle? s, FontWeight w, double spacing) => s?.copyWith(
    fontWeight: w,
    letterSpacing: spacing,
    color: p.text,
    fontFeatures: tabular,
  );
  TextStyle? body(TextStyle? s, double spacing, [Color? color]) =>
      s?.copyWith(letterSpacing: spacing, color: color, fontFeatures: tabular);
  return t.copyWith(
    displayLarge: heading(t.displayLarge, FontWeight.w700, -1.5),
    displayMedium: heading(t.displayMedium, FontWeight.w700, -1.2),
    displaySmall: heading(t.displaySmall, FontWeight.w700, -1),
    headlineLarge: heading(t.headlineLarge, FontWeight.w700, -0.8),
    headlineMedium: heading(t.headlineMedium, FontWeight.w700, -0.6),
    headlineSmall: heading(t.headlineSmall, FontWeight.w700, -0.4),
    titleLarge: heading(t.titleLarge, FontWeight.w700, -0.3),
    titleMedium: heading(t.titleMedium, FontWeight.w600, -0.1),
    titleSmall: heading(t.titleSmall, FontWeight.w600, 0),
    bodyLarge: body(t.bodyLarge, 0),
    bodyMedium: body(t.bodyMedium, 0),
    bodySmall: body(t.bodySmall, 0, p.muted),
    labelLarge: body(t.labelLarge, 0),
    labelMedium: body(t.labelMedium, 0.1),
    labelSmall: body(t.labelSmall, 0.2),
  );
}
