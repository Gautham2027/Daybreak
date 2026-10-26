import 'package:daybreak/app.dart';
import 'package:daybreak/models/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/in_memory_storage.dart';
import 'fakes/test_app.dart';

void main() {
  testWidgets('first launch shows the intro; Get started opens the app', (
    tester,
  ) async {
    final providers = TestProviders();
    await tester.pumpWidget(providers.wrap(const DaybreakApp()));

    expect(find.text('Plan the day before it plans you.'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('learns your pace'), findsWidgets);
    expect(find.text('Try with demo data'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Nothing on your plate'), findsOneWidget);
    expect(providers.settings.settings.hasOnboarded, isTrue);
  });

  testWidgets('Skip goes straight to the app', (tester) async {
    final providers = TestProviders();
    await tester.pumpWidget(providers.wrap(const DaybreakApp()));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Try with demo data loads the sample week', (tester) async {
    final providers = TestProviders();
    await tester.pumpWidget(providers.wrap(const DaybreakApp()));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    // Show intro again from Settings.
    await providers.settings.updateSettings(
      providers.settings.settings.copyWith(hasOnboarded: false),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-2000, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-2000, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-2000, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Try with demo data'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(providers.tasks.openTasks, hasLength(6));
    expect(providers.settings.settings.demoMode, isTrue);
    expect(find.text('Demo mode'), findsOneWidget);
    expect(find.text('Plan my day'), findsOneWidget);
  });

  testWidgets('returning users skip the intro', (tester) async {
    await tester.pumpWidget(
      TestProviders(
        InMemoryStorage(settings: const Settings(hasOnboarded: true)),
      ).wrap(const DaybreakApp()),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('works with reduce motion on', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(TestProviders().wrap(const DaybreakApp()));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Try with demo data'), findsOneWidget);
  });
}
