import 'package:flutter/material.dart';

/// Daybreak's own colors (importance, commitments, breaks, the dawn
/// gradients) that the normal Material ColorScheme doesn't have.
/// Read them with `DaybreakColors.of(context)`.
@immutable
class DaybreakColors extends ThemeExtension<DaybreakColors> {
  const DaybreakColors({
    required this.importanceHigh,
    required this.importanceMedium,
    required this.importanceLow,
    required this.commitment,
    required this.breakColor,
    required this.success,
    required this.dawnMorning,
    required this.dawnAfternoon,
    required this.dawnEvening,
    required this.onDawn,
  });

  /// Accent colors for task importance (accent bars, dots, pills).
  final Color importanceHigh;
  final Color importanceMedium;
  final Color importanceLow;

  /// Accent for commitments (neutral, so tasks stand out).
  final Color commitment;

  /// Accent for breaks (light and quiet).
  final Color breakColor;

  /// Done / accurate.
  final Color success;

  /// The header's "dawn" gradient for each part of the day (top-left to
  /// bottom-right), and the text color that reads well on all three.
  final List<Color> dawnMorning;
  final List<Color> dawnAfternoon;
  final List<Color> dawnEvening;
  final Color onDawn;

  /// The palette from the theme, or the built-in light/dark palette if the
  /// theme doesn't have one (like a plain MaterialApp in tests).
  static DaybreakColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<DaybreakColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  /// The accent for a task's importance (1 = Low, 2 = Medium, 3 = High).
  /// Null (a deleted task) gets the neutral commitment color.
  Color importance(int? importance) => switch (importance) {
    3 => importanceHigh,
    2 => importanceMedium,
    1 => importanceLow,
    _ => commitment,
  };

  /// Morning before noon, afternoon until 5 PM, then evening.
  List<Color> dawnFor(DateTime time) {
    if (time.hour < 12) return dawnMorning;
    if (time.hour < 17) return dawnAfternoon;
    return dawnEvening;
  }

  static const light = DaybreakColors(
    importanceHigh: Color(0xFFE8590C),
    importanceMedium: Color(0xFFD4900A),
    importanceLow: Color(0xFF4F7CAC),
    commitment: Color(0xFF7D746C),
    breakColor: Color(0xFFB8AEA4),
    success: Color(0xFF2F9E5B),
    dawnMorning: [Color(0xFFFFE3D0), Color(0xFFFFBE8F)],
    dawnAfternoon: [Color(0xFFFFEDBF), Color(0xFFFFCB66)],
    dawnEvening: [Color(0xFFE2D6F3), Color(0xFFB4BCEC)],
    onDawn: Color(0xFF2B1A10),
  );

  static const dark = DaybreakColors(
    importanceHigh: Color(0xFFFF8B52),
    importanceMedium: Color(0xFFF2BE4E),
    importanceLow: Color(0xFF86AEE0),
    commitment: Color(0xFF9A93A6),
    breakColor: Color(0xFF59607A),
    success: Color(0xFF63D394),
    dawnMorning: [Color(0xFF4A2A22), Color(0xFF7A3A1C)],
    dawnAfternoon: [Color(0xFF4A3A16), Color(0xFF6E5214)],
    dawnEvening: [Color(0xFF2C2552), Color(0xFF1C2A5E)],
    onDawn: Color(0xFFFFF4EA),
  );

  @override
  DaybreakColors copyWith({
    Color? importanceHigh,
    Color? importanceMedium,
    Color? importanceLow,
    Color? commitment,
    Color? breakColor,
    Color? success,
    List<Color>? dawnMorning,
    List<Color>? dawnAfternoon,
    List<Color>? dawnEvening,
    Color? onDawn,
  }) {
    return DaybreakColors(
      importanceHigh: importanceHigh ?? this.importanceHigh,
      importanceMedium: importanceMedium ?? this.importanceMedium,
      importanceLow: importanceLow ?? this.importanceLow,
      commitment: commitment ?? this.commitment,
      breakColor: breakColor ?? this.breakColor,
      success: success ?? this.success,
      dawnMorning: dawnMorning ?? this.dawnMorning,
      dawnAfternoon: dawnAfternoon ?? this.dawnAfternoon,
      dawnEvening: dawnEvening ?? this.dawnEvening,
      onDawn: onDawn ?? this.onDawn,
    );
  }

  @override
  DaybreakColors lerp(DaybreakColors? other, double t) {
    if (other == null) return this;
    List<Color> lerpList(List<Color> a, List<Color> b) => [
      for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!,
    ];
    return DaybreakColors(
      importanceHigh: Color.lerp(importanceHigh, other.importanceHigh, t)!,
      importanceMedium: Color.lerp(
        importanceMedium,
        other.importanceMedium,
        t,
      )!,
      importanceLow: Color.lerp(importanceLow, other.importanceLow, t)!,
      commitment: Color.lerp(commitment, other.commitment, t)!,
      breakColor: Color.lerp(breakColor, other.breakColor, t)!,
      success: Color.lerp(success, other.success, t)!,
      dawnMorning: lerpList(dawnMorning, other.dawnMorning),
      dawnAfternoon: lerpList(dawnAfternoon, other.dawnAfternoon),
      dawnEvening: lerpList(dawnEvening, other.dawnEvening),
      onDawn: Color.lerp(onDawn, other.onDawn, t)!,
    );
  }
}
