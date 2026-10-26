import 'package:daybreak/models/commitment.dart';
import 'package:daybreak/models/planned_block.dart';
import 'package:daybreak/models/settings.dart';
import 'package:daybreak/models/task.dart';
import 'package:daybreak/screens/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/in_memory_storage.dart';
import 'fakes/test_app.dart';

DateTime todayAt(int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

/// Demo mode is on, so the plan always starts at 3:00 PM no matter when the
/// test runs: Essay (1/2) 3:00-3:50, Break, Essay (2/2) 4:00-4:40,
/// Practice 5:00-6:00.
TestProviders demoProviders() {
  final now = DateTime.now();
  return TestProviders(
    InMemoryStorage(
      tasks: [
        Task(
          id: 'essay',
          title: 'Essay',
          dueDate: DateTime(now.year, now.month, now.day + 1),
          importance: Task.high,
          estimateMin: 90,
          category: 'Homework',
          createdAt: now,
        ),
      ],
      commitments: [
        Commitment(
          id: 'practice',
          title: 'Practice',
          start: todayAt(17),
          end: todayAt(18),
        ),
      ],
      settings: const Settings(demoMode: true),
    ),
  );
}

Future<void> pumpToday(WidgetTester tester, TestProviders providers) async {
  // A tall phone-sized screen so the whole timeline is on screen.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    providers.wrap(const MaterialApp(home: TodayScreen())),
  );
}

void main() {
  testWidgets('shows the Plan my day card when there is no plan', (
    tester,
  ) async {
    await pumpToday(tester, demoProviders());

    expect(find.text('Demo mode'), findsOneWidget);
    expect(find.text('Plan my day'), findsOneWidget);
    expect(find.text('1 task · 1 hr 30 min · 1 commitment'), findsOneWidget);
    expect(find.text('Re-plan'), findsNothing);
  });

  testWidgets('shows task, break, and commitment blocks after planning', (
    tester,
  ) async {
    await pumpToday(tester, demoProviders());

    await tester.tap(find.text('Plan my day'));
    await tester.pumpAndSettle();

    expect(find.text('Plan my day'), findsNothing);
    expect(find.text('Re-plan'), findsOneWidget);
    // Both Pomodoro segments show the task name with a "1/2" / "2/2" badge.
    expect(find.text('Essay'), findsNWidgets(2));
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('10 min break'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);
    expect(find.text('3:00 – 3:50 PM · 50 min'), findsOneWidget);
    expect(find.text('Homework'), findsNWidgets(2));
    // In demo mode it's 3:00 PM, so the first block is happening now.
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
  });

  testWidgets('logging a block that is not the last one', (tester) async {
    final providers = demoProviders();
    await pumpToday(tester, providers);
    await tester.tap(find.text('Plan my day'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1/2'));
    await tester.pumpAndSettle();
    expect(find.text('Due tomorrow'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);

    // Prefilled with the block's planned 50 min.
    await tester.tap(find.text('Done with this block'));
    await tester.pumpAndSettle();

    expect(find.text('Did you finish the task?'), findsNothing);
    expect(find.text('Logged 50 min'), findsOneWidget);
    final first = providers.plan.todayBlocks.firstWhere(
      (b) => b.type == BlockType.task,
    );
    expect(first.isDone, isTrue);
    expect(first.actualMin, 50);
    expect(providers.tasks.byId('essay')!.loggedMin, 50);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('logging the last block and choosing Yes completes the task', (
    tester,
  ) async {
    final now = DateTime.now();
    final providers = TestProviders(
      InMemoryStorage(
        tasks: [
          Task(
            id: 'read',
            title: 'Read',
            dueDate: DateTime(now.year, now.month, now.day + 1),
            importance: Task.medium,
            estimateMin: 30,
            createdAt: now,
          ),
        ],
        settings: const Settings(demoMode: true),
      ),
    );
    await pumpToday(tester, providers);
    await tester.tap(find.text('Plan my day'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '30 min'));
    await tester.tap(find.text('Done with this block'));
    await tester.pumpAndSettle();

    expect(find.text('Did you finish the task?'), findsOneWidget);
    await tester.tap(find.text('Yes, done!'));
    await tester.pumpAndSettle();

    // Medium (20) + accurate (15). The only task block is done, so the
    // Clean Slate badge pops up too.
    expect(find.text('+35 XP · Accurate estimate!'), findsOneWidget);
    expect(find.text('Badge earned: Clean Slate'), findsOneWidget);
    await tester.tap(find.text('Nice!'));
    await tester.pumpAndSettle();

    expect(providers.tasks.byId('read')!.isDone, isTrue);
    expect(providers.stats.stats.xp, 35);
    expect(providers.stats.logs.single.actualMin, 30);
    expect(find.text('Lv 1'), findsOneWidget);
    expect(find.text('35 XP'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('Not yet keeps the task open and suggests re-planning', (
    tester,
  ) async {
    final now = DateTime.now();
    final providers = TestProviders(
      InMemoryStorage(
        tasks: [
          Task(
            id: 'read',
            title: 'Read',
            dueDate: DateTime(now.year, now.month, now.day + 1),
            importance: Task.medium,
            estimateMin: 30,
            createdAt: now,
          ),
        ],
        settings: const Settings(demoMode: true),
      ),
    );
    await pumpToday(tester, providers);
    await tester.tap(find.text('Plan my day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done with this block'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not yet'));
    await tester.pumpAndSettle();

    expect(
      find.text('No problem. Re-plan to fit in the rest.'),
      findsOneWidget,
    );
    expect(providers.tasks.byId('read')!.isDone, isFalse);
    expect(providers.tasks.byId('read')!.loggedMin, 30);
  });

  testWidgets('velocity card opens the explanation sheet', (tester) async {
    await pumpToday(tester, demoProviders());
    await tester.tap(find.text('logs to unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Your velocity'), findsOneWidget);
    expect(
      find.text('Log 3 tasks to unlock smart estimates (0/3)'),
      findsOneWidget,
    );
  });

  testWidgets('stale banner appears after tasks change', (tester) async {
    final providers = demoProviders();
    await pumpToday(tester, providers);
    await tester.tap(find.text('Plan my day'));
    await tester.pumpAndSettle();
    expect(find.textContaining('changed since you planned'), findsNothing);

    await providers.tasks.addTask(
      Task.create(
        title: 'Read',
        dueDate: DateTime.now(),
        importance: Task.low,
        estimateMin: 20,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('changed since you planned'), findsOneWidget);
  });

  testWidgets('past the work window: explains and lists overflow', (
    tester,
  ) async {
    final now = DateTime.now();
    // A work window that is always over: midnight to 12:05 AM... unless the
    // test runs in those 5 minutes, so skip then.
    if (now.hour == 0 && now.minute < 5) return;
    final providers = TestProviders(
      InMemoryStorage(
        tasks: [
          Task(
            id: 'essay',
            title: 'Essay',
            dueDate: DateTime(now.year, now.month, now.day + 1),
            importance: Task.high,
            estimateMin: 30,
            createdAt: now,
          ),
        ],
        settings: const Settings(workStartMinutes: 0, workEndMinutes: 5),
      ),
    );
    await pumpToday(tester, providers);
    await tester.tap(find.text('Plan my day'));
    await tester.pumpAndSettle();

    expect(find.text('Your work window has ended for today'), findsOneWidget);
    expect(find.text("Didn't fit today"), findsOneWidget);
    expect(find.text('30 min left · Due tomorrow'), findsOneWidget);
    expect(find.text('These will be first in line tomorrow.'), findsOneWidget);
  });

  testWidgets('planning works with reduce motion on', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpToday(tester, demoProviders());
    await tester.tap(find.text('Plan my day'));
    // No staggered fade or pulsing dot: everything is there right away.
    await tester.pump();
    await tester.pump();
    expect(find.text('10 min break'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });
}
