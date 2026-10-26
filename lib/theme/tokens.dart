import 'package:flutter/widgets.dart';

// Spacing, corner sizes, and animation timings used across the app, so
// everything stays consistent.

/// Spacing scale (4, 8, 12, 16, 24, 32).
abstract final class Spacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Side padding for every screen.
  static const double page = l;

  /// Gap between cards/sections on a screen.
  static const double section = xl;
}

/// Corner radii.
abstract final class Radii {
  /// Chips, pills, small badges.
  static const double chip = 12;

  /// Buttons and inputs.
  static const double control = 16;

  /// Cards (including timeline blocks).
  static const double card = 20;

  /// Bottom sheets and dialogs.
  static const double sheet = 28;

  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius chipRadius = BorderRadius.all(
    Radius.circular(chip),
  );
}

/// Animation timings. Use [Motion.of] so animations switch off when the
/// phone's "reduce motion" setting is on.
abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// Delay between items in a staggered list.
  static const Duration stagger = Duration(milliseconds: 45);

  /// One beat of the "now" dot's pulse.
  static const Duration pulse = Duration(milliseconds: 1200);

  /// True when the user asked the OS to reduce motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or zero when motion is reduced.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
