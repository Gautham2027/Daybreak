import 'package:daybreak/models/planned_block.dart';
import 'package:daybreak/models/settings.dart';
import 'package:daybreak/models/task.dart';
import 'package:daybreak/models/time_log.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daybreak/models/commitment.dart';
import 'package:daybreak/services/calendar_convert.dart';

import 'fakes/fake_calendar.dart';
import 'fakes/in_memory_storage.dart';
import 'fakes/test_app.dart';

DateTime t(int hour, [int minute = 0]) => DateTime(2026, 10, 26, hour, minute);

Task task(String title, int importance) => Task(
  id: title,
  title: title,
  dueDate: DateTime(2026, 10, 27),
  importance: importance,
  estimateMin: 30,
  createdAt: DateTime(2026, 10, 20),
);

TimeLog log(String id, int estimate, int actual, int minute) => TimeLog(
  id: id,
  taskId: 'x',
  estimateMin: estimate,
  actualMin: actual,
  loggedAt: t(12, minute),
);

void main() {
  group('StatsProvider', () {
    test('addLog recomputes velocity and counts only valid logs', () async {
      final providers = TestProviders();
      final stats = providers.stats;

      await stats.addLog(log('1', 30, 60, 1)); // r = 2.0
      expect(stats.stats.velocity, closeTo(1.3, 1e-9));
      expect(stats.stats.logCount, 1);
      expect(stats.appliedVelocity, 1.0);

      await stats.addLog(log('2', 10, 300, 2)); // r = 30, ignored
      expect(stats.stats.logCount, 1);

      await stats.addLog(log('3', 30, 60, 3));
      await stats.addLog(log('4', 30, 60, 4));
      expect(stats.stats.logCount, 3);
      expect(stats.appliedVelocity, closeTo(stats.stats.velocity, 1e-9));
      expect(stats.appliedVelocity, greaterThan(1.5));
      expect(stats.velocityMessage, startsWith('You usually take 1.'));

      // Saved to storage too.
      expect(providers.storage.getStats().logCount, 3);
      expect(providers.storage.getAllLogs(), hasLength(4));
    });
  });

  group('PlanProvider', () {
    test('planMyDay builds and saves today\'s plan', () async {
      final providers = TestProviders(
        InMemoryStorage(tasks: [task('a', Task.high), task('b', Task.low)]),
      );
      final plan = providers.plan;
      expect(plan.hasPlanForToday, isFalse);

      await plan.planMyDay(t(15));
      expect(plan.hasPlanForToday, isTrue);
      // a 3:00-3:30, b 3:30-3:50, break, b 4:00-4:10
      expect(plan.todayBlocks.map((b) => b.taskId), ['a', 'b', null, 'b']);
      expect(plan.overflowItems, isEmpty);
      expect(providers.storage.getPlan(t(9))!.blocks, hasLength(4));
    });

    test('replan keeps past/done blocks and skips done tasks', () async {
      final providers = TestProviders(
        InMemoryStorage(
          tasks: [
            task('a', Task.high),
            task('b', Task.medium),
            task('c', Task.low),
          ],
        ),
      );
      final plan = providers.plan;

      await plan.planMyDay(t(15));
      // a 3:00-3:30, b 3:30-3:50, break, b 4:00-4:10, c 4:10-4:40
      expect(plan.todayBlocks.first.taskId, 'a');

      final first = providers.tasks.tasks.first;
      await providers.tasks.updateTask(
        first.copyWith(isDone: true, completedAt: t(15, 30)),
      );
      await plan.replan(t(15, 40));

      final taskBlocks = plan.todayBlocks
          .where((b) => b.type == BlockType.task)
          .toList();
      // a's block ended before now, so it's kept; a isn't scheduled again.
      expect(taskBlocks.where((b) => b.taskId == 'a'), hasLength(1));
      expect(taskBlocks.first.start, t(15));
      // b and c are re-planned from 3:40: b 3:40-4:10, c 4:10-4:30,
      // break, c 4:40-4:50.
      final b = taskBlocks.singleWhere((b) => b.taskId == 'b');
      expect(b.start, t(15, 40));
      final c = taskBlocks.where((b) => b.taskId == 'c').toList();
      expect(c.map((b) => b.start), [t(16, 10), t(16, 40)]);
    });

    test('plan goes stale when tasks change, and replan clears it', () async {
      final providers = TestProviders(
        InMemoryStorage(tasks: [task('a', Task.high)]),
      );
      final plan = providers.plan;
      // No plan yet: changes don't count as stale.
      await providers.tasks.addTask(task('b', Task.low));
      expect(plan.isStale, isFalse);

      await plan.planMyDay(t(15));
      expect(plan.isStale, isFalse);
      expect(providers.storage.getPlan(t(9))!.createdAt, isNotNull);

      await providers.tasks.addTask(task('c', Task.medium));
      expect(plan.isStale, isTrue);

      await plan.replan(t(15));
      expect(plan.isStale, isFalse);

      await providers.settings.updateSettings(
        providers.settings.settings.copyWith(bufferMin: 20),
      );
      expect(plan.isStale, isTrue);
    });

    test('demo mode plans from workStart regardless of the clock', () async {
      final providers = TestProviders(
        InMemoryStorage(
          tasks: [task('a', Task.high)],
          settings: const Settings(demoMode: true),
        ),
      );
      await providers.plan.planMyDay(t(23, 30));
      expect(providers.plan.todayBlocks.single.start, t(15));
    });

    test('loads a saved plan on startup', () async {
      final storage = InMemoryStorage(tasks: [task('a', Task.high)]);
      await TestProviders(storage).plan.planMyDay(DateTime.now());

      final reopened = TestProviders(storage).plan;
      expect(reopened.hasPlanForToday, isTrue);
    });
  });

  group('ProgressController', () {
    Task essay({int estimateMin = 90}) => Task(
      id: 'essay',
      title: 'Essay',
      dueDate: DateTime(2026, 10, 27),
      importance: Task.high,
      estimateMin: estimateMin,
      createdAt: DateTime(2026, 10, 20),
    );

    test('logBlock adds loggedMin and reports the last block', () async {
      final providers = TestProviders(InMemoryStorage(tasks: [essay()]));
      await providers.plan.planMyDay(t(15));
      List<PlannedBlock> blocks() =>
          providers.plan.todayBlocks.where((b) => b.taskId == 'essay').toList();
      expect(blocks(), hasLength(2)); // 50 / break / 40

      final firstIsLast = await providers.progress.logBlock(blocks().first, 55);
      expect(firstIsLast, isFalse);
      expect(blocks().first.isDone, isTrue);
      expect(blocks().first.actualMin, 55);
      expect(providers.tasks.byId('essay')!.loggedMin, 55);
      expect(providers.tasks.byId('essay')!.isDone, isFalse);

      final secondIsLast = await providers.progress.logBlock(blocks().last, 40);
      expect(secondIsLast, isTrue);
      expect(providers.tasks.byId('essay')!.loggedMin, 95);
      // Following the plan doesn't make it stale.
      expect(providers.plan.isStale, isFalse);
    });

    test('completeTask: log, XP, streak, done, blocks done', () async {
      final providers = TestProviders(InMemoryStorage(tasks: [essay()]));
      await providers.plan.planMyDay(t(15));

      final result = await providers.progress.completeTask(
        providers.tasks.byId('essay')!,
        95,
        t(17),
      );
      // High (30) + accurate: 95 vs 90 is within 15% (+15).
      expect(result.xpGained, 45);
      expect(result.wasAccurate, isTrue);
      expect(providers.stats.stats.xp, 45);
      expect(providers.stats.stats.streak, 1);
      expect(providers.stats.logs.single.estimateMin, 90);
      expect(providers.stats.logs.single.actualMin, 95);
      expect(providers.tasks.byId('essay')!.isDone, isTrue);
      expect(providers.tasks.byId('essay')!.completedAt, t(17));
      expect(
        providers.plan.todayBlocks
            .where((b) => b.taskId == 'essay')
            .every((b) => b.isDone),
        isTrue,
      );
      // Every task block done = Clean Slate.
      expect(result.newBadges, contains('Clean Slate'));
    });

    test('velocity changes the plan after 3 logs', () async {
      Task task(String id) => Task(
        id: id,
        title: id,
        dueDate: DateTime(2026, 10, 27),
        importance: Task.medium,
        estimateMin: 30,
        createdAt: DateTime(2026, 10, 20),
      );
      final providers = TestProviders(
        InMemoryStorage(tasks: [task('a'), task('b'), task('c'), task('d')]),
      );
      final progress = providers.progress;
      for (final id in ['a', 'b']) {
        await progress.completeTask(providers.tasks.byId(id)!, 60, t(16));
        expect(providers.stats.appliedVelocity, 1.0);
      }
      await progress.completeTask(providers.tasks.byId('c')!, 60, t(16));
      // r = 2.0 three times: 1.3 -> 1.51 -> 1.657
      expect(providers.stats.stats.velocity, closeTo(1.657, 1e-9));
      expect(providers.stats.appliedVelocity, closeTo(1.657, 1e-9));

      // 30 min * 1.657 = 49.7 -> 50 min, so 'd' gets a 50 min block.
      await providers.plan.planMyDay(t(15));
      final d = providers.plan.todayBlocks.singleWhere((b) => b.taskId == 'd');
      expect(d.end.difference(d.start).inMinutes, 50);
    });

    test('undoCompletion reverses XP and the log, keeps streak', () async {
      final providers = TestProviders(InMemoryStorage(tasks: [essay()]));
      final progress = providers.progress;
      await progress.completeTask(providers.tasks.byId('essay')!, 90, t(17));
      expect(providers.stats.stats.xp, 45);

      await progress.undoCompletion(providers.tasks.byId('essay')!);
      expect(providers.stats.stats.xp, 0);
      expect(providers.stats.logs, isEmpty);
      expect(providers.storage.getAllLogs(), isEmpty);
      expect(providers.stats.stats.velocity, 1.0);
      expect(providers.stats.stats.logCount, 0);
      expect(providers.stats.stats.streak, 1);
      expect(providers.tasks.byId('essay')!.isDone, isFalse);
      expect(providers.tasks.byId('essay')!.completedAt, isNull);
    });

    test('skip then undo takes back the base XP', () async {
      final providers = TestProviders(InMemoryStorage(tasks: [essay()]));
      final progress = providers.progress;
      final result = await progress.completeTask(
        providers.tasks.byId('essay')!,
        null,
        t(17),
      );
      expect(result.xpGained, 30);
      expect(providers.stats.logs, isEmpty);
      await progress.undoCompletion(providers.tasks.byId('essay')!);
      expect(providers.stats.stats.xp, 0);
    });

    test('timer: start, pause, resume, stop', () async {
      final stats = TestProviders().stats;
      await stats.startTimer('essay', t(15));
      expect(stats.stats.timerIsRunning, isTrue);
      await stats.pauseTimer(t(15, 10));
      expect(stats.stats.timerIsRunning, isFalse);
      expect(stats.stats.timerElapsed(t(16)), const Duration(minutes: 10));
      await stats.startTimer('essay', t(16));
      expect(stats.stats.timerElapsed(t(16, 5)), const Duration(minutes: 15));
      expect(await stats.stopTimer(t(16, 5)), 15);
      expect(stats.stats.hasTimer, isFalse);
    });

    test('completing the timer task clears the timer', () async {
      final providers = TestProviders(InMemoryStorage(tasks: [essay()]));
      await providers.stats.startTimer('essay', t(15));
      await providers.progress.completeTask(
        providers.tasks.byId('essay')!,
        90,
        t(16, 30),
      );
      expect(providers.stats.stats.hasTimer, isFalse);
    });
  });

  group('calendar auto-import', () {
    // Uses the real "today" because commitments are loaded for today.
    final now = DateTime.now();
    DateTime at(int h) => DateTime(now.year, now.month, now.day, h);
    final settings = const Settings(
      demoMode: true,
      selectedCalendarIds: ['school'],
    );

    test('Plan my day imports calendar events first', () async {
      final calendar = FakeCalendarService(
        events: [
          CalendarEventData(id: 'e', title: 'Lab', start: at(15), end: at(16)),
        ],
      );
      final providers = TestProviders(
        InMemoryStorage(tasks: [task('a', Task.high)], settings: settings),
        calendar,
      );
      await providers.plan.planMyDay(now);

      expect(
        providers.commitments.commitments.single.source,
        CommitmentSource.calendar,
      );
      final titles = providers.plan.todayBlocks.map((b) => b.title);
      expect(titles, contains('Lab'));
      // The task goes after the event + 10 min buffer.
      final a = providers.plan.todayBlocks.singleWhere((b) => b.taskId == 'a');
      expect(a.start, DateTime(now.year, now.month, now.day, 16, 10));
    });

    test('an import error never blocks planning', () async {
      final providers = TestProviders(
        InMemoryStorage(tasks: [task('a', Task.high)], settings: settings),
        FakeCalendarService(failReads: true),
      );
      await providers.plan.planMyDay(now);
      expect(providers.plan.hasPlanForToday, isTrue);
      expect(providers.plan.todayBlocks.single.taskId, 'a');
    });

    test('skipped when auto-import is off', () async {
      final calendar = FakeCalendarService(
        events: [
          CalendarEventData(id: 'e', title: 'Lab', start: at(15), end: at(16)),
        ],
      );
      final providers = TestProviders(
        InMemoryStorage(
          tasks: [task('a', Task.high)],
          settings: settings.copyWith(autoImportBeforePlanning: false),
        ),
        calendar,
      );
      await providers.plan.planMyDay(now);
      expect(providers.commitments.commitments, isEmpty);
    });
  });

  group('edge cases', () {
    Task essay({int loggedMin = 0}) => Task(
      id: 'essay',
      title: 'Essay',
      dueDate: DateTime(2026, 10, 27),
      importance: Task.high,
      estimateMin: 90,
      createdAt: DateTime(2026, 10, 20),
      loggedMin: loggedMin,
    );

    test(
      'deleting a planned task removes its blocks and marks stale',
      () async {
        final providers = TestProviders(
          InMemoryStorage(tasks: [essay(), task('b', Task.low)]),
        );
        await providers.plan.planMyDay(t(15));
        expect(
          providers.plan.todayBlocks.any((b) => b.taskId == 'essay'),
          isTrue,
        );

        await providers.tasks.deleteTask('essay');
        expect(
          providers.plan.todayBlocks.any((b) => b.taskId == 'essay'),
          isFalse,
        );
        expect(providers.plan.todayBlocks.any((b) => b.taskId == 'b'), isTrue);
        expect(providers.plan.isStale, isTrue);
        // The saved plan is updated too.
        expect(
          providers.storage
              .getPlan(t(9))!
              .blocks
              .any((b) => b.taskId == 'essay'),
          isFalse,
        );
      },
    );

    test('editing the estimate after logging keeps loggedMin', () async {
      final providers = TestProviders(InMemoryStorage(tasks: [essay()]));
      await providers.plan.planMyDay(t(15));
      final first = providers.plan.todayBlocks.first;
      await providers.progress.logBlock(first, 50);

      final logged = providers.tasks.byId('essay')!;
      await providers.tasks.updateTask(logged.copyWith(estimateMin: 120));
      expect(providers.tasks.byId('essay')!.loggedMin, 50);
      expect(providers.plan.isStale, isTrue);

      await providers.plan.replan(t(16));
      // 120 - 50 logged = 70 left: 50 / break / 20, after the kept block.
      final open = providers.plan.todayBlocks
          .where((b) => b.taskId == 'essay' && !b.isDone)
          .toList();
      expect(
        open.fold<int>(
          0,
          (sum, b) => sum + b.end.difference(b.start).inMinutes,
        ),
        70,
      );
    });

    test('planning with zero open tasks', () async {
      final providers = TestProviders();
      await providers.plan.planMyDay(t(15));
      expect(providers.plan.hasPlanForToday, isTrue);
      expect(providers.plan.todayBlocks, isEmpty);
      expect(providers.plan.overflowItems, isEmpty);
    });

    test(
      'commitments filling the whole window: everything overflows',
      () async {
        final now = DateTime.now();
        DateTime at(int h) => DateTime(now.year, now.month, now.day, h);
        final providers = TestProviders(
          InMemoryStorage(
            tasks: [task('a', Task.high)],
            commitments: [
              Commitment(
                id: 'job',
                title: 'Work shift',
                start: at(14),
                end: at(23),
              ),
            ],
            settings: const Settings(demoMode: true),
          ),
        );
        await providers.plan.planMyDay(now);
        expect(providers.plan.todayBlocks.single.title, 'Work shift');
        expect(providers.plan.overflowItems.single.taskId, 'a');
      },
    );

    test('timer survives a restart; stopping at 0 minutes is fine', () async {
      final storage = InMemoryStorage();
      await TestProviders(storage).stats.startTimer('essay', t(15));

      // "Restart": new providers reading the same storage.
      final stats = TestProviders(storage).stats;
      expect(stats.stats.runningTimerTaskId, 'essay');
      expect(stats.stats.timerElapsed(t(15, 20)), const Duration(minutes: 20));

      await stats.startTimer('other', t(16));
      expect(await stats.stopTimer(t(16)), 0);
      expect(stats.stats.hasTimer, isFalse);
    });

    test('a new day drops yesterday\'s plan', () async {
      final now = DateTime.now();
      final providers = TestProviders(
        InMemoryStorage(tasks: [task('a', Task.high)]),
      );
      await providers.plan.planMyDay(now);
      expect(providers.plan.hasPlanForToday, isTrue);

      providers.plan.checkForNewDay(now);
      expect(providers.plan.hasPlanForToday, isTrue);

      providers.plan.checkForNewDay(now.add(const Duration(days: 1)));
      expect(providers.plan.hasPlanForToday, isFalse);
    });
  });
}
