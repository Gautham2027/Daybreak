import 'dart:convert';

import 'package:daybreak/models/commitment.dart';
import 'package:daybreak/models/overflow_item.dart';
import 'package:daybreak/models/plan_record.dart';
import 'package:daybreak/models/planned_block.dart';
import 'package:daybreak/models/settings.dart';
import 'package:daybreak/models/task.dart';
import 'package:daybreak/models/time_log.dart';
import 'package:daybreak/models/user_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sends a JSON map through a real encode/decode, like saving to disk.
Map<String, dynamic> roundTrip(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  group('Task', () {
    final task = Task(
      id: 'task-1',
      title: 'Essay draft',
      dueDate: DateTime(2026, 10, 30),
      importance: Task.high,
      estimateMin: 45,
      category: 'Homework',
      isDone: true,
      createdAt: DateTime(2026, 10, 26, 9, 15),
      completedAt: DateTime(2026, 10, 27, 18, 0),
    );

    test('round trip keeps every field', () {
      final copy = Task.fromJson(roundTrip(task.toJson()));
      expect(copy.id, task.id);
      expect(copy.title, task.title);
      expect(copy.dueDate, task.dueDate);
      expect(copy.importance, task.importance);
      expect(copy.estimateMin, task.estimateMin);
      expect(copy.category, task.category);
      expect(copy.isDone, task.isDone);
      expect(copy.createdAt, task.createdAt);
      expect(copy.completedAt, task.completedAt);
    });

    test('missing optional fields use defaults', () {
      final copy = Task.fromJson({
        'id': 'task-2',
        'title': 'Old task',
        'dueDate': '2026-11-01T00:00:00.000',
      });
      expect(copy.importance, Task.medium);
      expect(copy.estimateMin, 30);
      expect(copy.category, isNull);
      expect(copy.isDone, isFalse);
      expect(copy.completedAt, isNull);
      expect(copy.loggedMin, 0);
    });

    test('loggedMin round trips', () {
      final copy = Task.fromJson(
        roundTrip(task.copyWith(loggedMin: 25).toJson()),
      );
      expect(copy.loggedMin, 25);
    });

    test('dueDate is normalized to midnight', () {
      final withTime = task.copyWith(dueDate: DateTime(2026, 10, 30, 17, 45));
      expect(withTime.dueDate, DateTime(2026, 10, 30));

      final fromJson = Task.fromJson({
        'id': 'task-3',
        'title': 'x',
        'dueDate': '2026-10-30T23:59:00.000',
      });
      expect(fromJson.dueDate, DateTime(2026, 10, 30));
    });

    test('importanceLabel', () {
      expect(task.copyWith(importance: 1).importanceLabel, 'Low');
      expect(task.copyWith(importance: 2).importanceLabel, 'Medium');
      expect(task.copyWith(importance: 3).importanceLabel, 'High');
    });

    test('create fills id and createdAt', () {
      final a = Task.create(
        title: 'a',
        dueDate: DateTime.now(),
        importance: 2,
        estimateMin: 30,
      );
      final b = Task.create(
        title: 'b',
        dueDate: DateTime.now(),
        importance: 2,
        estimateMin: 30,
      );
      expect(a.id, isNotEmpty);
      expect(a.id, isNot(b.id));
      expect(DateTime.now().difference(a.createdAt).inSeconds, lessThan(5));
    });

    test('copyWith can clear completedAt', () {
      final undone = task.copyWith(isDone: false, clearCompletedAt: true);
      expect(undone.completedAt, isNull);
    });

    test('equality is by id', () {
      expect(task.copyWith(title: 'Renamed'), task);
    });
  });

  group('Commitment', () {
    final commitment = Commitment(
      id: 'c-1',
      title: 'Soccer practice',
      start: DateTime(2026, 10, 26, 16, 0),
      end: DateTime(2026, 10, 26, 17, 30),
      source: CommitmentSource.calendar,
    );

    test('round trip keeps every field', () {
      final copy = Commitment.fromJson(roundTrip(commitment.toJson()));
      expect(copy.id, commitment.id);
      expect(copy.title, commitment.title);
      expect(copy.start, commitment.start);
      expect(copy.end, commitment.end);
      expect(copy.source, CommitmentSource.calendar);
    });

    test('missing or unknown source defaults to manual', () {
      final json = commitment.toJson()..remove('source');
      expect(Commitment.fromJson(json).source, CommitmentSource.manual);
      json['source'] = 'something-new';
      expect(Commitment.fromJson(json).source, CommitmentSource.manual);
    });
  });

  group('PlannedBlock', () {
    final block = PlannedBlock(
      taskId: 'task-1',
      title: 'Essay draft',
      start: DateTime(2026, 10, 26, 15, 0),
      end: DateTime(2026, 10, 26, 15, 45),
      type: BlockType.task,
      isChunk: true,
      isDone: true,
    );

    test('round trip keeps every field', () {
      final copy = PlannedBlock.fromJson(roundTrip(block.toJson()));
      expect(copy.taskId, block.taskId);
      expect(copy.title, block.title);
      expect(copy.start, block.start);
      expect(copy.end, block.end);
      expect(copy.type, block.type);
      expect(copy.isChunk, isTrue);
      expect(copy.isDone, isTrue);
    });

    test('break type is saved as "break"', () {
      final breakBlock = block.copyWith(type: BlockType.breakTime);
      expect(breakBlock.toJson()['type'], 'break');
      expect(
        PlannedBlock.fromJson(breakBlock.toJson()).type,
        BlockType.breakTime,
      );
    });

    test('missing optional fields use defaults', () {
      final copy = PlannedBlock.fromJson({
        'title': 'Break',
        'start': '2026-10-26T15:45:00.000',
        'end': '2026-10-26T15:50:00.000',
        'type': 'unknown',
      });
      expect(copy.taskId, isNull);
      expect(copy.type, BlockType.task);
      expect(copy.isChunk, isFalse);
      expect(copy.isDone, isFalse);
      expect(copy.actualMin, isNull);
      expect(
        PlannedBlock.fromJson(roundTrip(block.copyWith(actualMin: 40).toJson()))
            .actualMin,
        40,
      );
    });
  });

  group('PlanRecord', () {
    test('round trip keeps blocks and overflow ids', () {
      final record = PlanRecord(
        blocks: [
          PlannedBlock(
            title: 'Break',
            start: DateTime(2026, 10, 26, 15, 50),
            end: DateTime(2026, 10, 26, 15, 55),
            type: BlockType.breakTime,
          ),
        ],
        overflow: const [
          OverflowItem(taskId: 'task-9', remainingMinutes: 25, isUrgent: true),
        ],
      );
      final copy = PlanRecord.fromJson(roundTrip(record.toJson()));
      expect(copy.blocks.single.toJson(), record.blocks.single.toJson());
      expect(copy.overflowTaskIds, ['task-9']);
      expect(copy.overflow.single.remainingMinutes, 25);
      expect(copy.overflow.single.isUrgent, isTrue);
    });

    test('old plans with only overflowTaskIds still load', () {
      final copy = PlanRecord.fromJson({
        'blocks': [],
        'overflowTaskIds': ['a', 'b'],
      });
      expect(copy.overflowTaskIds, ['a', 'b']);
      expect(copy.overflow.first.remainingMinutes, 0);
    });

    test('empty json gives an empty plan', () {
      final copy = PlanRecord.fromJson({});
      expect(copy.blocks, isEmpty);
      expect(copy.overflowTaskIds, isEmpty);
    });
  });

  group('TimeLog', () {
    final log = TimeLog(
      id: 'log-1',
      taskId: 'task-1',
      estimateMin: 30,
      actualMin: 42,
      loggedAt: DateTime(2026, 10, 26, 19, 5),
    );

    test('round trip keeps every field', () {
      final copy = TimeLog.fromJson(roundTrip(log.toJson()));
      expect(copy.id, log.id);
      expect(copy.taskId, log.taskId);
      expect(copy.estimateMin, 30);
      expect(copy.actualMin, 42);
      expect(copy.loggedAt, log.loggedAt);
    });

    test('missing fields do not crash', () {
      final copy = TimeLog.fromJson({'id': 'log-2'});
      expect(copy.taskId, '');
      expect(copy.estimateMin, 0);
      expect(copy.actualMin, 0);
      expect(copy.xpAwarded, 0);
      expect(copy.wasAccurate, isFalse);
      final full = TimeLog.fromJson(
        roundTrip(log.copyWith(xpAwarded: 45, wasAccurate: true).toJson()),
      );
      expect(full.xpAwarded, 45);
      expect(full.wasAccurate, isTrue);
    });
  });

  group('UserStats', () {
    test('round trip keeps every field', () {
      final stats = UserStats(
        velocity: 1.4,
        logCount: 5,
        xp: 230,
        streak: 3,
        lastActiveDate: DateTime(2026, 10, 25),
        badges: {'Sharpshooter': DateTime(2026, 10, 24, 18, 30)},
        bestStreak: 6,
      );
      final copy = UserStats.fromJson(roundTrip(stats.toJson()));
      expect(copy.velocity, 1.4);
      expect(copy.logCount, 5);
      expect(copy.xp, 230);
      expect(copy.streak, 3);
      expect(copy.lastActiveDate, DateTime(2026, 10, 25));
      expect(copy.badges, {'Sharpshooter': DateTime(2026, 10, 24, 18, 30)});
      expect(copy.bestStreak, 6);
    });

    test('empty json uses defaults', () {
      final copy = UserStats.fromJson({});
      expect(copy.velocity, 1.0);
      expect(copy.logCount, 0);
      expect(copy.xp, 0);
      expect(copy.streak, 0);
      expect(copy.lastActiveDate, isNull);
      expect(copy.badges, isEmpty);
      expect(copy.bestStreak, 0);
      expect(copy.accurateInARow, 0);
      expect(copy.runningTimerTaskId, isNull);
      expect(copy.runningTimerStartedAt, isNull);
      expect(copy.hasTimer, isFalse);
    });

    test('old badge lists migrate to a map with the last active date', () {
      final copy = UserStats.fromJson({
        'badges': ['Early Bird', 'Clean Slate'],
        'lastActiveDate': '2026-10-20T00:00:00.000',
        'streak': 4,
      });
      expect(copy.badges, {
        'Early Bird': DateTime(2026, 10, 20),
        'Clean Slate': DateTime(2026, 10, 20),
      });
      // bestStreak is never below the current streak.
      expect(copy.bestStreak, 4);
    });

    test('timer fields round trip', () {
      final stats = UserStats(
        accurateInARow: 3,
        runningTimerTaskId: 'task-1',
        runningTimerStartedAt: DateTime(2026, 10, 26, 15, 30),
        timerAccumulatedSec: 90,
      );
      final copy = UserStats.fromJson(roundTrip(stats.toJson()));
      expect(copy.accurateInARow, 3);
      expect(copy.runningTimerTaskId, 'task-1');
      expect(copy.runningTimerStartedAt, DateTime(2026, 10, 26, 15, 30));
      expect(
        copy.timerElapsed(DateTime(2026, 10, 26, 15, 31)),
        const Duration(seconds: 150),
      );
      expect(copy.copyWith(clearTimer: true).hasTimer, isFalse);
    });

    test('velocity saved as a whole number still reads as double', () {
      expect(UserStats.fromJson({'velocity': 2}).velocity, 2.0);
    });
  });

  group('Settings', () {
    test('round trip keeps every field', () {
      const settings = Settings(
        workStartMinutes: 14 * 60,
        workEndMinutes: 21 * 60,
        breakEveryMin: 45,
        breakLengthMin: 10,
        bufferMin: 15,
        minChunkMin: 20,
      );
      final copy = Settings.fromJson(roundTrip(settings.toJson()));
      expect(copy.toJson(), settings.toJson());
    });

    test('empty json uses the default settings', () {
      final copy = Settings.fromJson({});
      expect(copy.workStartMinutes, 15 * 60);
      expect(copy.workEndMinutes, 22 * 60);
      expect(copy.breakEveryMin, 50);
      expect(copy.breakLengthMin, 10);
      expect(copy.bufferMin, 10);
      expect(copy.minChunkMin, 25);
    });

    test('old saved 5 min break is upgraded to 10 on load', () {
      // Saved before version 2: no 'version' field.
      final old = Settings.fromJson({'breakLengthMin': 5, 'bufferMin': 15});
      expect(old.breakLengthMin, 10);
      expect(old.bufferMin, 15);
      // A different old choice is kept.
      expect(Settings.fromJson({'breakLengthMin': 15}).breakLengthMin, 15);
      // A 5 min break chosen after the upgrade is kept.
      final chosen = const Settings(breakLengthMin: 5).toJson();
      expect(Settings.fromJson(chosen).breakLengthMin, 5);
    });
  });
}
