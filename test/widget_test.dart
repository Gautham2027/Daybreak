import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daybreak/app.dart';

import 'package:daybreak/models/settings.dart';

import 'fakes/in_memory_storage.dart';
import 'fakes/test_app.dart';

void main() {
  testWidgets('Home shell shows the four tabs and switches between them', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TestProviders(
        InMemoryStorage(settings: const Settings(hasOnboarded: true)),
      ).wrap(const DaybreakApp()),
    );

    Finder navLabel(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

    expect(navLabel('Today'), findsOneWidget);
    expect(navLabel('Tasks'), findsOneWidget);
    expect(navLabel('Stats'), findsOneWidget);
    expect(navLabel('Settings'), findsOneWidget);

    await tester.tap(navLabel('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Level 1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sharpshooter'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Sharpshooter'), findsOneWidget);
    expect(find.textContaining('velocity chart will show up'), findsOneWidget);
    await tester.tap(navLabel('Today'));
    await tester.pumpAndSettle();

    // Today is the first tab shown; with no tasks it offers to go to Tasks.
    expect(find.text('Nothing on your plate'), findsOneWidget);
    await tester.tap(find.text('Go to Tasks'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    await tester.tap(navLabel('Today'));
    await tester.pumpAndSettle();

    await tester.tap(navLabel('Tasks'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
  });

  testWidgets('no stretch effect when scrolling past the end on Android', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestProviders(
        InMemoryStorage(settings: const Settings(hasOnboarded: true)),
      ).wrap(const DaybreakApp()),
    );
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
