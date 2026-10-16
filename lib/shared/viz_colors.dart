import 'package:flutter/material.dart';

/// Chart colours: validated categorical slots (colour-blind safe as an
/// adjacent pair in both themes) and reserved status colours. Status colours
/// always appear with an icon and a label, never alone.
class VizColors {
  const VizColors._({
    required this.series1,
    required this.series2,
    required this.series3,
    required this.track,
  });

  static VizColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  static const _light = VizColors._(
    series1: Color(0xFF2A78D6),
    series2: Color(0xFFEB6834),
    series3: Color(0xFF8B54D8),
    track: Color(0xFFE4E3DF),
  );

  static const _dark = VizColors._(
    series1: Color(0xFF3987E5),
    series2: Color(0xFFD95926),
    series3: Color(0xFF9D70E6),
    track: Color(0xFF383835),
  );

  /// Categorical slot 1 (blue).
  final Color series1;

  /// Categorical slot 2 (orange).
  final Color series2;

  /// Categorical slot 3 (purple), for a gauge that must not reuse the blue
  /// of the one next to it.
  final Color series3;

  /// Unfilled part of a bar.
  final Color track;

  static const good = Color(0xFF0CA30C);
  static const warning = Color(0xFFFAB219);
  static const critical = Color(0xFFD03B3B);
}
