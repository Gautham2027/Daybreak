import 'package:flutter/material.dart';

import 'colors.dart';
import 'tokens.dart';

/// Warm sunrise orange that the whole color scheme is generated from.
const Color seedColor = Color(0xFFF57C00);

const String _fontFamily = 'PlusJakartaSans';

/// Daybreak's light or dark theme.
ThemeData buildDaybreakTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colors = _colorScheme(brightness);
  final textTheme = _textTheme(colors);

  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.control),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colors,
    fontFamily: _fontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: colors.surface,
    extensions: [isDark ? DaybreakColors.dark : DaybreakColors.light],
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.headlineSmall,
    ),
    // Cards: no shadows, a soft 1px outline, and a gentle surface tint.
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark
          ? colors.surfaceContainerLow
          : colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.cardRadius,
        side: BorderSide(color: colors.outlineVariant),
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: Spacing.l,
        vertical: Spacing.xs + 2,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: controlShape,
        minimumSize: const Size(64, 48),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: controlShape,
        minimumSize: const Size(64, 48),
        side: BorderSide(color: colors.outlineVariant),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: controlShape,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: controlShape,
        side: BorderSide(color: colors.outlineVariant),
        textStyle: textTheme.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: Radii.chipRadius,
        side: BorderSide(color: colors.outlineVariant),
      ),
      labelStyle: textTheme.labelLarge,
      backgroundColor: colors.surfaceContainerLowest,
      selectedColor: colors.primaryContainer,
      showCheckmark: false,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.primary,
      foregroundColor: colors.onPrimary,
      elevation: 2,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      extendedTextStyle: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: isDark
          ? colors.surfaceContainerLow
          : colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colors.primaryContainer,
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelMedium?.copyWith(
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? colors.onSurface
              : colors.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colors.onPrimaryContainer
              : colors.onSurfaceVariant,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: colors.outline,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sheet),
      ),
      titleTextStyle: textTheme.titleLarge,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colors.onInverseSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colors.onSurfaceVariant,
      titleTextStyle: textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.control),
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 6,
      inactiveTrackColor: colors.surfaceContainerHighest,
      valueIndicatorTextStyle: textTheme.labelLarge?.copyWith(
        color: colors.onPrimary,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.primary,
      linearTrackColor: colors.surfaceContainerHighest,
      circularTrackColor: colors.surfaceContainerHighest,
    ),
    dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 1),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
    ),
  );
}

/// fromSeed, with warmer neutrals: off-white (not pure white) in light mode,
/// deep navy (not pure black) in dark mode.
ColorScheme _colorScheme(Brightness brightness) {
  final base = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  if (brightness == Brightness.light) {
    return base.copyWith(
      // A vivid deep orange (fromSeed's tone is a muted brown). White text
      // on it has a contrast ratio above 5:1.
      primary: const Color(0xFFC2410C),
      onPrimary: const Color(0xFFFFFFFF),
      surface: const Color(0xFFFBF7F2),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF7F1EA),
      surfaceContainer: const Color(0xFFF2EBE3),
      surfaceContainerHigh: const Color(0xFFECE4DB),
      surfaceContainerHighest: const Color(0xFFE6DDD3),
      onSurface: const Color(0xFF231A14),
      onSurfaceVariant: const Color(0xFF6A5F57),
      outline: const Color(0xFF9A8E84),
      outlineVariant: const Color(0xFFE8DED3),
    );
  }
  return base.copyWith(
    surface: const Color(0xFF111522),
    surfaceContainerLowest: const Color(0xFF0C0F18),
    surfaceContainerLow: const Color(0xFF171C2A),
    surfaceContainer: const Color(0xFF1C2232),
    surfaceContainerHigh: const Color(0xFF232A3B),
    surfaceContainerHighest: const Color(0xFF2C3446),
    onSurface: const Color(0xFFEEE9E4),
    onSurfaceVariant: const Color(0xFFB7B1AC),
    outline: const Color(0xFF7C8193),
    outlineVariant: const Color(0xFF2E3547),
  );
}

/// A clear hierarchy: big bold display for greetings and key numbers,
/// medium titles, comfortable body text, small muted labels. Every style
/// uses tabular figures so times and numbers line up.
TextTheme _textTheme(ColorScheme colors) {
  const tabular = [FontFeature.tabularFigures()];
  TextStyle style(
    double size,
    FontWeight weight, {
    double height = 1.25,
    double letterSpacing = 0,
    Color? color,
  }) => TextStyle(
    fontFamily: _fontFamily,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    color: color ?? colors.onSurface,
    fontFeatures: tabular,
  );

  return TextTheme(
    displayLarge: style(52, FontWeight.w800, letterSpacing: -1.5),
    displayMedium: style(44, FontWeight.w800, letterSpacing: -1),
    displaySmall: style(34, FontWeight.w800, letterSpacing: -0.8),
    headlineLarge: style(30, FontWeight.w800, letterSpacing: -0.6),
    headlineMedium: style(28, FontWeight.w800, letterSpacing: -0.6),
    headlineSmall: style(22, FontWeight.w700, letterSpacing: -0.3),
    titleLarge: style(20, FontWeight.w700, letterSpacing: -0.2),
    titleMedium: style(16, FontWeight.w700),
    titleSmall: style(14, FontWeight.w700),
    bodyLarge: style(16, FontWeight.w400, height: 1.45),
    bodyMedium: style(14, FontWeight.w400, height: 1.4),
    bodySmall: style(
      12,
      FontWeight.w500,
      height: 1.35,
      color: colors.onSurfaceVariant,
    ),
    labelLarge: style(14, FontWeight.w600),
    labelMedium: style(12, FontWeight.w600, letterSpacing: 0.1),
    labelSmall: style(11, FontWeight.w600, letterSpacing: 0.3),
  );
}
