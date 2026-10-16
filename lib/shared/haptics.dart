import 'package:flutter/services.dart';

/// Haptic feedback, in one place so the app feels the same everywhere.
///
/// These use the impact and selection patterns, which Flutter maps onto the
/// Taptic Engine on iOS and the matching haptic constants on Android. Devices
/// without a motor, and users who turned system haptics off, get nothing.
abstract final class Haptics {
  /// Off when the user turned haptics off in the app's settings.
  static bool enabled = true;

  /// A pull to refresh that went far enough to start.
  static void refresh() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  /// A light tick for choosing something: a tab, a switch, a key.
  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// An action the user confirmed, or one that just finished.
  static void confirm() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// A destructive action the user confirmed, or something that failed.
  static void warning() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}
