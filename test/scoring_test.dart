import 'package:daybreak/models/task.dart';
import 'package:daybreak/services/format.dart';
import 'package:daybreak/services/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 26);

Task makeTask({
  String title = 'Task',
  required DateTime dueDate,
  int importance = Task.medium,
  int estimateMin = 30,
}) {
  return Task(
    id: title,
    title: title,
    dueDate: dueDate,
    importance: importance,
    estimateMin: estimateMin,
    createdAt: today,
  );
}

void main() {
  group('priorityScore', () {
    test('High task due tomorrow = 30 + 20 = 50', () {
      final task = makeTask(
        dueDate: DateTime(2026, 10, 27),
        importance: Task.high,
      );
      expect(priorityScore(task, today), 50);
    });

    test('Low task overdue = 10 + 40 + 50 = 100', () {
      final task = makeTask(
        dueDate: DateTime(2026, 10, 24),
        importance: Task.low,
      );
      expect(priorityScore(task, today), 100);
    });

    test('Medium task due today = 20 + 40 = 60', () {
      final task = makeTask(dueDate: today);
      expect(priorityScore(task, today), 60);
      expect(isOverdue(task.dueDate, today), isFalse);
    });

    test('Medium task due in a week = 20 + 40/8 = 25', () {
      final task = makeTask(dueDate: DateTime(2026, 11, 2));
      expect(daysUntilDue(task.dueDate, today), 7);
      expect(priorityScore(task, today), 25);
    });
  });

  group('daysUntilDue', () {
    test('is floored at 0 for overdue tasks', () {
      expect(daysUntilDue(DateTime(2026, 10, 20), today), 0);
      expect(isOverdue(DateTime(2026, 10, 20), today), isTrue);
    });

    test('time of day does not matter', () {
      final lateTonight = DateTime(2026, 10, 26, 23, 59);
      final earlyMorning = DateTime(2026, 10, 26, 0, 1);
      final due = DateTime(2026, 10, 27, 8, 0);
      expect(daysUntilDue(due, lateTonight), 1);
      expect(daysUntilDue(due, earlyMorning), 1);
      expect(isOverdue(DateTime(2026, 10, 26), lateTonight), isFalse);
    });
  });

  group('sortByPriority', () {
    test('highest score first', () {
      final week = makeTask(
        title: 'week',
        dueDate: DateTime(2026, 11, 2),
        importance: Task.high,
      );
      final overdue = makeTask(
        title: 'overdue',
        dueDate: DateTime(2026, 10, 25),
        importance: Task.low,
      );
      final tomorrow = makeTask(
        title: 'tomorrow',
        dueDate: DateTime(2026, 10, 27),
      );
      final sorted = sortByPriority([week, tomorrow, overdue], today);
      expect(sorted.map((t) => t.title), ['overdue', 'tomorrow', 'week']);
    });

    test('ties break by due date, then length, then title', () {
      // All overdue Medium tasks score the same (20 + 40 + 50 = 110).
      final older = makeTask(title: 'older', dueDate: DateTime(2026, 10, 20));
      final longer = makeTask(
        title: 'longer',
        dueDate: DateTime(2026, 10, 25),
        estimateMin: 60,
      );
      final shorterB = makeTask(title: 'b', dueDate: DateTime(2026, 10, 25));
      final shorterA = makeTask(title: 'a', dueDate: DateTime(2026, 10, 25));

      final sorted = sortByPriority([longer, shorterB, older, shorterA], today);
      expect(sorted.map((t) => t.title), ['older', 'a', 'b', 'longer']);
    });

    test('does not change the original list', () {
      final a = makeTask(title: 'a', dueDate: DateTime(2026, 11, 2));
      final b = makeTask(title: 'b', dueDate: today);
      final original = [a, b];
      sortByPriority(original, today);
      expect(original, [a, b]);
    });
  });

  group('format', () {
    test('formatEstimate', () {
      expect(formatEstimate(30), '30 min');
      expect(formatEstimate(60), '1 hr');
      expect(formatEstimate(90), '1 hr 30 min');
    });

    test('dueLabel', () {
      expect(dueLabel(DateTime(2026, 10, 25), today), 'Overdue by 1 day');
      expect(dueLabel(DateTime(2026, 10, 23), today), 'Overdue by 3 days');
      expect(dueLabel(today, today), 'Due today');
      expect(dueLabel(DateTime(2026, 10, 27), today), 'Due tomorrow');
      expect(dueLabel(DateTime(2026, 10, 28), today), 'Due Wed, Oct 28');
    });

    test('formDateLabel', () {
      expect(formDateLabel(today, today), 'Today, Oct 26');
      expect(formDateLabel(DateTime(2026, 10, 27), today), 'Tomorrow, Oct 27');
      expect(formDateLabel(DateTime(2026, 10, 25), today), 'Yesterday, Oct 25');
      expect(formDateLabel(DateTime(2026, 10, 28), today), 'Wed, Oct 28');
    });
  });

  test('splitSegmentTitle', () {
    expect(splitSegmentTitle('Essay (1/2)'), (title: 'Essay', badge: '1/2'));
    expect(splitSegmentTitle('Essay (part 1)'), (
      title: 'Essay',
      badge: 'part 1',
    ));
    expect(splitSegmentTitle('Essay'), (title: 'Essay', badge: null));
    expect(splitSegmentTitle('Read (ch. 7) for English'), (
      title: 'Read (ch. 7) for English',
      badge: null,
    ));
  });

  test('dueGroupFor', () {
    expect(dueGroupFor(DateTime(2026, 10, 25), today), DueGroup.overdue);
    expect(dueGroupFor(today, today), DueGroup.today);
    expect(dueGroupFor(DateTime(2026, 10, 27), today), DueGroup.tomorrow);
    expect(dueGroupFor(DateTime(2026, 11, 1), today), DueGroup.thisWeek);
    expect(dueGroupFor(DateTime(2026, 11, 2), today), DueGroup.later);
  });
}
