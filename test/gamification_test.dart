import 'package:daybreak/models/planned_block.dart';
import 'package:daybreak/models/task.dart';
import 'package:daybreak/models/time_log.dart';
import 'package:daybreak/models/user_stats.dart';
import 'package:daybreak/services/gamification.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 26);

Task makeTask({
  int importance = Task.medium,
  int estimateMin = 30,
  int dueInDays = 1,
}) {
  return Task(
    id: 'task',
    title: 'Task',
    dueDate: DateTime(2026, 10, 26 + dueInDays),
    importance: importance,
    estimateMin: estimateMin,
    createdAt: DateTime(2026, 10, 20),
  );
}

PlannedBlock taskBlock({bool isDone = false}) => PlannedBlock(
  taskId: 'task',
  title: 'Task',
  start: DateTime(2026, 10, 26, 15),
  end: DateTime(2026, 10, 26, 15, 30),
  type: BlockType.task,
  isDone: isDone,
);

void main() {
  group('isAccurate', () {
    test('within 15% either way', () {
      expect(isAccurate(100, 100), isTrue);
      expect(isAccurate(100, 110), isTrue);
      expect(isAccurate(100, 90), isTrue);
    });

    test('exactly 15% counts', () {
      expect(isAccurate(100, 115), isTrue);
      expect(isAccurate(100, 85), isTrue);
      expect(isAccurate(20, 23), isTrue);
      expect(isAccurate(60, 69), isTrue);
    });

    test('just over 15% does not', () {
      expect(isAccurate(100, 116), isFalse);
      expect(isAccurate(100, 84), isFalse);
      expect(isAccurate(30, 42), isFalse);
    });

    test('no estimate is never accurate', () {
      expect(isAccurate(0, 0), isFalse);
    });
  });

  group('XP', () {
    test('10 per importance, +15 when accurate', () {
      expect(xpForCompletion(makeTask(importance: Task.low), 60), 10);
      expect(xpForCompletion(makeTask(importance: Task.high), 60), 30);
      expect(xpForCompletion(makeTask(importance: Task.high), 30), 45);
      expect(xpForCompletion(makeTask(importance: Task.medium), 33), 35);
    });

    test('baseXp has no bonus', () {
      expect(baseXp(makeTask(importance: Task.high)), 30);
    });
  });

  group('streaks', () {
    test('first ever completion starts at 1', () {
      expect(updateStreak(0, null, today), 1);
    });

    test('same day: unchanged', () {
      expect(updateStreak(4, today, today), 4);
    });

    test('next day: +1, including just across midnight', () {
      final lateYesterday = DateTime(2026, 10, 25, 23, 59);
      final justAfterMidnight = DateTime(2026, 10, 26, 0, 1);
      expect(updateStreak(4, lateYesterday, justAfterMidnight), 5);
    });

    test('a missed day resets to 1', () {
      expect(updateStreak(7, DateTime(2026, 10, 24), today), 1);
    });

    test('across a month boundary', () {
      expect(updateStreak(2, DateTime(2026, 10, 31), DateTime(2026, 11, 1)), 3);
    });

    test('displayedStreak shows 0 after a missed day', () {
      expect(displayedStreak(5, today, today), 5);
      expect(displayedStreak(5, DateTime(2026, 10, 25), today), 5);
      expect(displayedStreak(5, DateTime(2026, 10, 24), today), 0);
      expect(displayedStreak(0, null, today), 0);
    });
  });

  group('levels', () {
    test('level boundaries', () {
      expect(level(0), 1);
      expect(level(199), 1);
      expect(level(200), 2);
      expect(level(399), 2);
      expect(level(400), 3);
    });

    test('levelProgress', () {
      expect(levelProgress(0), 0.0);
      expect(levelProgress(100), 0.5);
      expect(levelProgress(199), closeTo(0.995, 1e-9));
      expect(levelProgress(200), 0.0);
      expect(levelProgress(340), 0.7);
    });
  });

  group('badges', () {
    test('Sharpshooter when accurateInARow reaches 5', () {
      List<String> badgesWith(int inARow) => newBadges(
        stats: UserStats(accurateInARow: inARow),
        task: makeTask(),
        completedAt: today,
        todayBlocks: const [],
      );
      expect(badgesWith(4), isEmpty);
      expect(badgesWith(5), [sharpshooter]);
    });

    test('Early Bird when finished 2+ days before due', () {
      List<String> badgesFor(int dueInDays) => newBadges(
        stats: const UserStats(),
        task: makeTask(dueInDays: dueInDays),
        completedAt: DateTime(2026, 10, 26, 22),
        todayBlocks: const [],
      );
      expect(badgesFor(1), isEmpty);
      expect(badgesFor(2), [earlyBird]);
      expect(badgesFor(7), [earlyBird]);
    });

    test('Clean Slate when every task block today is done', () {
      List<String> badgesFor(List<PlannedBlock> blocks) => newBadges(
        stats: const UserStats(),
        task: makeTask(),
        completedAt: today,
        todayBlocks: blocks,
      );
      expect(badgesFor([taskBlock(isDone: true)]), [cleanSlate]);
      expect(
        badgesFor([taskBlock(isDone: true), taskBlock(isDone: false)]),
        isEmpty,
      );
      // An empty plan doesn't count.
      expect(badgesFor(const []), isEmpty);
    });

    test('each badge is earned only once', () {
      final result = newBadges(
        stats: UserStats(
          accurateInARow: 6,
          badges: {sharpshooter: today, cleanSlate: today},
        ),
        task: makeTask(dueInDays: 3),
        completedAt: today,
        todayBlocks: [taskBlock(isDone: true)],
      );
      expect(result, [earlyBird]);
    });
  });

  group('applyCompletion', () {
    test('logs original estimate, awards XP, updates streak', () {
      final update = applyCompletion(
        stats: UserStats(streak: 2, lastActiveDate: DateTime(2026, 10, 25)),
        logs: const [],
        task: makeTask(importance: Task.high, estimateMin: 30),
        actualMin: 32,
        now: DateTime(2026, 10, 26, 16),
        todayBlocks: const [],
        logId: 'log-1',
      );
      expect(update.log!.estimateMin, 30);
      expect(update.log!.actualMin, 32);
      expect(update.log!.wasAccurate, isTrue);
      expect(update.log!.xpAwarded, 45);
      expect(update.result.xpGained, 45);
      expect(update.result.wasAccurate, isTrue);
      expect(update.stats.xp, 45);
      expect(update.stats.streak, 3);
      expect(update.stats.lastActiveDate, today);
      expect(update.stats.accurateInARow, 1);
      expect(update.stats.logCount, 1);
    });

    test('inaccurate resets accurateInARow', () {
      final update = applyCompletion(
        stats: const UserStats(accurateInARow: 3),
        logs: const [],
        task: makeTask(),
        actualMin: 60,
        now: today,
        todayBlocks: const [],
        logId: 'x',
      );
      expect(update.stats.accurateInARow, 0);
      expect(update.result.wasAccurate, isFalse);
    });

    test('skip: base XP, no log, velocity unchanged', () {
      final update = applyCompletion(
        stats: const UserStats(velocity: 1.4, logCount: 4, accurateInARow: 2),
        logs: const [],
        task: makeTask(importance: Task.high),
        actualMin: null,
        now: today,
        todayBlocks: const [],
        logId: 'x',
      );
      expect(update.log, isNull);
      expect(update.result.xpGained, 30);
      expect(update.stats.velocity, 1.4);
      expect(update.stats.logCount, 4);
      expect(update.stats.accurateInARow, 2);
    });

    test('reports level ups', () {
      final update = applyCompletion(
        stats: const UserStats(xp: 190),
        logs: const [],
        task: makeTask(importance: Task.low),
        actualMin: 30,
        now: today,
        todayBlocks: const [],
        logId: 'x',
      );
      expect(update.result.leveledUp, isTrue);
      expect(update.result.newLevel, 2);
      expect(update.result.totalXp, 215);
    });

    test('new badges are saved on the stats', () {
      final update = applyCompletion(
        stats: const UserStats(),
        logs: const [],
        task: makeTask(dueInDays: 5),
        actualMin: 30,
        now: today,
        todayBlocks: [taskBlock(isDone: true)],
        logId: 'x',
      );
      expect(update.result.newBadges, [earlyBird, cleanSlate]);
      expect(update.stats.badges, {earlyBird: today, cleanSlate: today});
    });

    test('bestStreak grows with the streak and never shrinks', () {
      final grew = applyCompletion(
        stats: UserStats(
          streak: 4,
          bestStreak: 4,
          lastActiveDate: DateTime(2026, 10, 25),
        ),
        logs: const [],
        task: makeTask(),
        actualMin: 30,
        now: today,
        todayBlocks: const [],
        logId: 'x',
      );
      expect(grew.stats.streak, 5);
      expect(grew.stats.bestStreak, 5);

      final reset = applyCompletion(
        stats: UserStats(
          streak: 4,
          bestStreak: 9,
          lastActiveDate: DateTime(2026, 10, 20),
        ),
        logs: const [],
        task: makeTask(),
        actualMin: 30,
        now: today,
        todayBlocks: const [],
        logId: 'x',
      );
      expect(reset.stats.streak, 1);
      expect(reset.stats.bestStreak, 9);
    });
  });

  group('undo', () {
    test('lastLogFor finds the newest log for a task', () {
      final logs = [
        TimeLog(
          id: 'old',
          taskId: 'task',
          estimateMin: 30,
          actualMin: 30,
          loggedAt: DateTime(2026, 10, 20),
        ),
        TimeLog(
          id: 'new',
          taskId: 'task',
          estimateMin: 30,
          actualMin: 30,
          loggedAt: DateTime(2026, 10, 25),
        ),
        TimeLog(
          id: 'other',
          taskId: 'other',
          estimateMin: 30,
          actualMin: 30,
          loggedAt: DateTime(2026, 10, 26),
        ),
      ];
      expect(lastLogFor('task', logs)!.id, 'new');
      expect(lastLogFor('missing', logs), isNull);
    });

    test('applyUndo takes back XP (never below 0) and keeps streak', () {
      final undone = applyUndo(
        stats: const UserStats(xp: 40, streak: 3, velocity: 1.3, logCount: 1),
        remainingLogs: const [],
        xpToRemove: 45,
      );
      expect(undone.xp, 0);
      expect(undone.streak, 3);
      expect(undone.velocity, 1.0);
      expect(undone.logCount, 0);
    });
  });
}
