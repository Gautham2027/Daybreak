import 'package:daybreak/models/plan_record.dart';
import 'package:daybreak/models/planned_block.dart';
import 'package:daybreak/models/task.dart';
import 'package:daybreak/models/time_log.dart';
import 'package:daybreak/services/stats.dart';
import 'package:flutter_test/flutter_test.dart';

// Wednesday Oct 28 2026; the week is Mon Oct 26 - Sun Nov 1.
final today = DateTime(2026, 10, 28);

TimeLog log(int estimate, int actual, DateTime at) => TimeLog(
  id: '$at',
  taskId: 't',
  estimateMin: estimate,
  actualMin: actual,
  loggedAt: at,
);

Task doneTask(String id, DateTime? completedAt) => Task(
  id: id,
  title: id,
  dueDate: today,
  importance: Task.medium,
  estimateMin: 30,
  createdAt: DateTime(2026, 10, 1),
  isDone: completedAt != null,
  completedAt: completedAt,
);

PlannedBlock block(BlockType type, {bool done = false}) => PlannedBlock(
  title: 'x',
  start: DateTime(2026, 10, 26, 15),
  end: DateTime(2026, 10, 26, 15, 50),
  type: type,
  isDone: done,
);

void main() {
  group('accuracyRate', () {
    test('null with no logs', () {
      expect(accuracyRate(const []), isNull);
    });

    test('share of logs within 15%', () {
      final logs = [
        log(30, 30, today), // accurate
        log(30, 34, today), // accurate (13%)
        log(30, 45, today), // not
        log(60, 40, today), // not
      ];
      expect(accuracyRate(logs), 0.5);
    });

    test('logs without an estimate are ignored', () {
      expect(accuracyRate([log(0, 30, today), log(30, 30, today)]), 1.0);
    });
  });

  group('velocityHistory', () {
    test('running velocity after each valid log, oldest first', () {
      final points = velocityHistory([
        log(30, 30, DateTime(2026, 10, 27)), // 1.0 -> 1.0
        log(30, 60, DateTime(2026, 10, 26)), // first: 2.0 -> 1.3
        log(10, 300, DateTime(2026, 10, 28)), // r = 30, skipped
      ]);
      expect(points.map((p) => p.time), [
        DateTime(2026, 10, 26),
        DateTime(2026, 10, 27),
      ]);
      expect(points[0].velocity, closeTo(1.3, 1e-9));
      expect(points[1].velocity, closeTo(1.21, 1e-9));
    });

    test('empty with no valid logs', () {
      expect(velocityHistory([log(10, 300, today)]), isEmpty);
    });
  });

  group('week', () {
    test('weekStart is Monday, even on Sunday or Monday', () {
      expect(weekStart(today), DateTime(2026, 10, 26));
      expect(weekStart(DateTime(2026, 11, 1, 23)), DateTime(2026, 10, 26));
      expect(weekStart(DateTime(2026, 10, 26, 0, 5)), DateTime(2026, 10, 26));
    });

    test('weekDays are Mon - Sun across a month boundary', () {
      final days = weekDays(today);
      expect(days.first, DateTime(2026, 10, 26));
      expect(days.last, DateTime(2026, 11, 1));
      expect(days, hasLength(7));
    });

    test('weeklySummary counts only this week', () {
      final summary = weeklySummary(
        tasks: [
          doneTask('mon', DateTime(2026, 10, 26, 16)),
          doneTask('sun', DateTime(2026, 11, 1, 22)),
          doneTask('lastWeek', DateTime(2026, 10, 25, 20)),
          doneTask('nextWeek', DateTime(2026, 11, 2, 9)),
          doneTask('open', null),
        ],
        logs: [
          log(30, 45, DateTime(2026, 10, 26, 16)),
          log(60, 155, DateTime(2026, 10, 28, 18)),
          log(30, 500, DateTime(2026, 10, 25, 18)), // last week
        ],
        weekPlans: [
          PlanRecord(
            blocks: [
              block(BlockType.task, done: true),
              block(BlockType.task, done: true),
              block(BlockType.task),
              block(BlockType.breakTime, done: true),
              block(BlockType.commitment, done: true),
            ],
          ),
          PlanRecord(blocks: [block(BlockType.task, done: true)]),
        ],
        today: today,
      );
      expect(summary.tasksCompleted, 2);
      expect(summary.focusMinutes, 200); // shows as "3 hr 20 min"
      expect(summary.pomodoros, 3);
    });
  });
}
