import 'package:daybreak/models/task.dart';
import 'package:daybreak/screens/tasks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/in_memory_storage.dart';
import 'fakes/test_app.dart';

Task makeTask(String title, {required int dueInDays, int importance = 2}) {
  final now = DateTime.now();
  return Task(
    id: title,
    title: title,
    dueDate: DateTime(now.year, now.month, now.day + dueInDays),
    importance: importance,
    estimateMin: 30,
    createdAt: now,
  );
}

Future<void> pumpTasksScreen(
  WidgetTester tester, {
  List<Task> tasks = const [],
}) {
  return tester.pumpWidget(
    TestProviders(InMemoryStorage(tasks: tasks))
        .wrap(const MaterialApp(home: TasksScreen())),
  );
}

void main() {
  testWidgets('shows the empty state when there are no tasks', (tester) async {
    await pumpTasksScreen(tester);
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.text('Tap + to add your first task.'), findsOneWidget);
  });

  testWidgets('adding a task through the form shows it in the list', (
    tester,
  ) async {
    await pumpTasksScreen(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New task'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Read chapter 4');
    await tester.tap(find.text('High'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('New task'), findsNothing);
    expect(find.text('Read chapter 4'), findsOneWidget);
    // One detail line: "Due tomorrow · 30 min".
    expect(find.textContaining('Due tomorrow · 30 min'), findsOneWidget);
    expect(find.text('TOMORROW · 1'), findsOneWidget);
  });

  testWidgets('Save is disabled until the title has text', (tester) async {
    await pumpTasksScreen(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    FilledButton saveButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
    expect(saveButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(saveButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Essay');
    await tester.pump();
    expect(saveButton().onPressed, isNotNull);
  });

  testWidgets('tasks appear in priority order', (tester) async {
    await pumpTasksScreen(
      tester,
      tasks: [
        makeTask('Big project', dueInDays: 7, importance: Task.high),
        makeTask('Return library book', dueInDays: -1, importance: Task.low),
      ],
    );

    final overdueY = tester.getTopLeft(find.text('Return library book')).dy;
    final projectY = tester.getTopLeft(find.text('Big project')).dy;
    expect(overdueY, lessThan(projectY));
    expect(find.textContaining('Overdue by 1 day'), findsOneWidget);
    // Grouped by when they're due.
    expect(find.text('OVERDUE · 1'), findsOneWidget);
    expect(find.text('LATER · 1'), findsOneWidget);
  });

  testWidgets('toggling the checkbox moves a task to Completed', (
    tester,
  ) async {
    await pumpTasksScreen(tester, tasks: [makeTask('Laundry', dueInDays: 0)]);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    // Asks how long it took, prefilled with the 30 min estimate.
    expect(find.text('How long did it take?'), findsOneWidget);
    expect(find.text('30 min'), findsWidgets);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    // Medium (20) + accurate (15).
    expect(find.text('+35 XP · Accurate estimate!'), findsOneWidget);
    // Finished 0 days early and no plan, so no badge dialogs.
    expect(find.textContaining('Badge earned'), findsNothing);

    // Completed section starts collapsed, so the task is hidden.
    expect(find.text('Completed (1)'), findsOneWidget);
    expect(find.text('Laundry'), findsNothing);
    expect(find.text('All caught up'), findsOneWidget);

    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();
    final title = tester.widget<Text>(find.text('Laundry'));
    expect(title.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('swipe to delete, then undo restores the task', (tester) async {
    await pumpTasksScreen(tester, tasks: [makeTask('Dishes', dueInDays: 1)]);

    await tester.drag(find.text('Dishes'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Dishes'), findsNothing);
    expect(find.text('Task deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Dishes'), findsOneWidget);
  });

  testWidgets('tapping a task opens the form in edit mode', (tester) async {
    await pumpTasksScreen(tester, tasks: [makeTask('Essay', dueInDays: 2)]);

    await tester.tap(find.text('Essay'));
    await tester.pumpAndSettle();
    expect(find.text('Edit task'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Essay draft');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Essay draft'), findsOneWidget);
  });

  testWidgets('Skip completes with base XP; unchecking undoes it', (
    tester,
  ) async {
    final providers = TestProviders(
      InMemoryStorage(
        tasks: [makeTask('Laundry', dueInDays: 0).copyWith(loggedMin: 25)],
      ),
    );
    await tester.pumpWidget(
      providers.wrap(const MaterialApp(home: TasksScreen())),
    );
    expect(find.textContaining('25 min logged'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('+20 XP'), findsOneWidget);
    expect(providers.stats.stats.xp, 20);
    expect(providers.stats.logs, isEmpty);

    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(providers.stats.stats.xp, 0);
    expect(providers.tasks.byId('Laundry')!.isDone, isFalse);
  });
}
