import 'package:daybreak/app.dart';
import 'package:daybreak/models/task.dart';
import 'package:daybreak/services/demo_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/in_memory_storage.dart';
import 'fakes/test_app.dart';

// Visits every screen on a small phone (iPhone SE: 375x667) with large
// text (1.3x) and a very long task title, in light and dark mode. Any
// overflow or layout error fails the test.

const _longTitle =
    'Finish the AP World History DBQ essay draft and email it to Ms. '
    'Rodriguez before class tomorrow morning';

Future<TestProviders> _pumpDemoApp(
  WidgetTester tester,
  Brightness brightness,
) async {
  tester.view.physicalSize = const Size(750, 1334);
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  final now = DateTime.now();
  final storage = InMemoryStorage();
  await loadDemoData(storage, now);
  await storage.saveTask(
    Task(
      id: 'long',
      title: _longTitle,
      dueDate: DateTime(now.year, now.month, now.day + 1),
      importance: Task.high,
      estimateMin: 25,
      category: 'Homework',
      createdAt: now,
      loggedMin: 15,
    ),
  );
  final providers = TestProviders(storage);
  await tester.pumpWidget(providers.wrap(const DaybreakApp()));
  await tester.pumpAndSettle();
  return providers;
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> _scrollThrough(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable).hitTestable();
  if (scrollables.evaluate().isEmpty) return;
  for (var i = 0; i < 8; i++) {
    await tester.drag(scrollables.first, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final brightness in Brightness.values) {
    group('small screen, 1.3x text, ${brightness.name} mode', () {
      testWidgets('Today: plan card, timeline, log sheet, velocity sheet', (
        tester,
      ) async {
        final providers = await _pumpDemoApp(tester, brightness);
        expect(find.text('Plan my day'), findsOneWidget);

        await tester.ensureVisible(find.text('Plan my day'));
        await tester.tap(find.text('Plan my day'));
        await tester.pumpAndSettle();
        expect(find.text('Re-plan'), findsOneWidget);

        // Timer chip in the header.
        await providers.stats.startTimer('demo-chem', DateTime.now());
        await tester.pump();

        await tester.ensureVisible(
          find.textContaining('Study for chem quiz').first,
        );
        await tester.tap(find.textContaining('Study for chem quiz').first);
        await tester.pumpAndSettle();
        expect(find.text('Done with this block'), findsOneWidget);
        await _scrollThrough(tester);
        Navigator.of(tester.element(find.text('Minutes spent'))).pop();
        await tester.pumpAndSettle();

        await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('pace'));
        await tester.tap(find.text('pace'));
        await tester.pumpAndSettle();
        expect(find.text('Your velocity'), findsOneWidget);
        Navigator.of(tester.element(find.text('Your velocity'))).pop();
        await tester.pumpAndSettle();

        await _scrollThrough(tester);
      });

      testWidgets('Tasks list, task form, completion dialog', (tester) async {
        await _pumpDemoApp(tester, brightness);
        await tester.tap(_tab('Tasks'));
        await tester.pumpAndSettle();
        await _scrollThrough(tester);

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        expect(find.text('New task'), findsOneWidget);
        await _scrollThrough(tester);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(Scrollable).hitTestable().first,
          const Offset(0, 3000),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Checkbox).first);
        await tester.pumpAndSettle();
        expect(find.text('How long did it take?'), findsOneWidget);
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        // Let the celebration SnackBar / badge dialogs finish.
        while (find.text('Nice!').evaluate().isNotEmpty) {
          await tester.tap(find.text('Nice!'));
          await tester.pumpAndSettle();
        }
      });

      testWidgets('Commitments screen and form', (tester) async {
        await _pumpDemoApp(tester, brightness);
        await tester.ensureVisible(find.text('Add commitments first'));
        await tester.tap(find.text('Add commitments first'));
        await tester.pumpAndSettle();
        expect(find.text("Today's commitments"), findsOneWidget);
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        expect(find.text('New commitment'), findsOneWidget);
      });

      testWidgets('Stats and Settings', (tester) async {
        await _pumpDemoApp(tester, brightness);
        await tester.tap(_tab('Stats'));
        await tester.pumpAndSettle();
        expect(find.text('Level 2'), findsOneWidget);
        await _scrollThrough(tester);

        await tester.tap(_tab('Settings'));
        await tester.pumpAndSettle();
        await _scrollThrough(tester);
      });

      testWidgets('Onboarding', (tester) async {
        final providers = await _pumpDemoApp(tester, brightness);
        await providers.settings.updateSettings(
          providers.settings.settings.copyWith(hasOnboarded: false),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Try with demo data'), findsOneWidget);
      });
    });
  }
}
