import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

class DaybreakApp extends StatelessWidget {
  const DaybreakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daybreak',
      debugShowCheckedModeBanner: false,
      theme: buildDaybreakTheme(Brightness.light),
      darkTheme: buildDaybreakTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      scrollBehavior: const _NoStretchScrollBehavior(),
      home: const _Root(),
    );
  }
}

/// Turns off the "stretch" effect Android shows when you scroll past the
/// top or bottom of a list. Scrolling itself works the same.
class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

/// The intro on first launch, then the main app.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final hasOnboarded = context.select<SettingsProvider, bool>(
      (s) => s.settings.hasOnboarded,
    );
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.slow),
      child: hasOnboarded
          ? const HomeShell(key: ValueKey('home'))
          : const OnboardingScreen(key: ValueKey('intro')),
    );
  }
}
