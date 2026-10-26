import 'dart:io';

import 'package:daybreak/models/commitment.dart';
import 'package:daybreak/models/overflow_item.dart';
import 'package:daybreak/models/plan_record.dart';
import 'package:daybreak/models/planned_block.dart';
import 'package:daybreak/models/settings.dart';
import 'package:daybreak/models/task.dart';
import 'package:daybreak/models/time_log.dart';
import 'package:daybreak/models/user_stats.dart';
import 'package:daybreak/services/storage.dart';
import 'package:hive/hive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StorageService storage;

  setUp(() async {
    Hive.init(Directory.systemTemp.createTempSync('daybreak_test').path);
    storage = StorageService();
    await storage.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  Task makeTask(String title) => Task.create(
    title: title,
    dueDate: DateTime(2026, 10, 27),
    importance: Task.medium,
    estimateMin: 30,
  );

  group('tasks', () {
    test('starts empty', () {
      expect(storage.getAllTasks(), isEmpty);
    });

    test('save, update, and delete', () async {
      final task = makeTask('Read chapter 4');
      await storage.saveTask(task);
      expect(storage.getAllTasks().single.title, 'Read chapter 4');

      await storage.saveTask(task.copyWith(title: 'Read chapter 5'));
      final tasks = storage.getAllTasks();
      expect(tasks, hasLength(1));
      expect(tasks.single.title, 'Read chapter 5');

      await storage.deleteTask(task.id);
      expect(storage.getAllTasks(), isEmpty);
    });
  });

  group('commitments', () {
    test('getCommitmentsForDay only returns that day', () async {
      final today = Commitment.create(
        title: 'Practice',
        start: DateTime(2026, 10, 26, 16),
        end: DateTime(2026, 10, 26, 17),
      );
      final tomorrow = Commitment.create(
        title: 'Dentist',
        start: DateTime(2026, 10, 27, 16),
        end: DateTime(2026, 10, 27, 17),
      );
      await storage.saveCommitment(today);
      await storage.saveCommitment(tomorrow);

      expect(storage.getAllCommitments(), hasLength(2));
      expect(storage.getCommitmentsForDay(DateTime(2026, 10, 26)), [today]);

      await storage.deleteCommitment(today.id);
      expect(storage.getCommitmentsForDay(DateTime(2026, 10, 26)), isEmpty);
    });
  });

  group('time logs', () {
    test('returned oldest first', () async {
      final newer = TimeLog(
        id: 'b',
        taskId: 't',
        estimateMin: 30,
        actualMin: 40,
        loggedAt: DateTime(2026, 10, 26, 20),
      );
      final older = newer.copyWith(loggedAt: DateTime(2026, 10, 25, 20));
      await storage.addLog(newer);
      await storage.addLog(TimeLog.fromJson({...older.toJson(), 'id': 'a'}));

      final logs = storage.getAllLogs();
      expect(logs.map((l) => l.id), ['a', 'b']);
    });
  });

  group('stats and settings', () {
    test('defaults when nothing is saved', () {
      expect(storage.getStats().toJson(), const UserStats().toJson());
      expect(storage.getSettings().toJson(), const Settings().toJson());
    });

    test('save and read back', () async {
      await storage.saveStats(
        UserStats(
          xp: 120,
          streak: 2,
          badges: {'Early Bird': DateTime(2026, 10, 26, 9)},
        ),
      );
      await storage.saveSettings(const Settings(bufferMin: 20));

      expect(storage.getStats().xp, 120);
      expect(storage.getStats().badges, {
        'Early Bird': DateTime(2026, 10, 26, 9),
      });
      expect(storage.getSettings().bufferMin, 20);
    });
  });

  group('plans', () {
    final day = DateTime(2026, 10, 26);

    test('getPlan is null when nothing saved', () {
      expect(storage.getPlan(day), isNull);
    });

    test('savePlan / getPlan round trip', () async {
      final blocks = [
        PlannedBlock(
          title: 'Practice',
          start: DateTime(2026, 10, 26, 16),
          end: DateTime(2026, 10, 26, 17),
          type: BlockType.commitment,
        ),
        PlannedBlock(
          taskId: 'task-1',
          title: 'Essay',
          start: DateTime(2026, 10, 26, 17, 10),
          end: DateTime(2026, 10, 26, 17, 40),
          type: BlockType.task,
          isChunk: true,
        ),
      ];
      await storage.savePlan(
        day,
        PlanRecord(
          blocks: blocks,
          overflow: const [
            OverflowItem(
              taskId: 'task-2',
              remainingMinutes: 40,
              isUrgent: true,
            ),
          ],
        ),
      );

      final plan = storage.getPlan(DateTime(2026, 10, 26, 21, 30))!;
      expect(plan.blocks.map((b) => b.toJson()), blocks.map((b) => b.toJson()));
      expect(plan.overflowTaskIds, ['task-2']);
      expect(plan.overflow.single.remainingMinutes, 40);
      expect(plan.overflow.single.isUrgent, isTrue);
      expect(storage.getPlan(DateTime(2026, 10, 27)), isNull);
    });
  });

  test('clearAll wipes everything', () async {
    await storage.saveTask(makeTask('a'));
    await storage.saveStats(const UserStats(xp: 50));
    await storage.savePlan(DateTime(2026, 10, 26), const PlanRecord());

    await storage.clearAll();

    expect(storage.getAllTasks(), isEmpty);
    expect(storage.getStats().xp, 0);
    expect(storage.getPlan(DateTime(2026, 10, 26)), isNull);
  });
}
