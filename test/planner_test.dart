import 'package:daybreak/models/commitment.dart';
import 'package:daybreak/models/planned_block.dart';
import 'package:daybreak/models/settings.dart';
import 'package:daybreak/models/task.dart';
import 'package:daybreak/services/planner.dart';
import 'package:flutter_test/flutter_test.dart';

// Default settings: work 3:00 PM - 10:00 PM, Pomodoro 50 min work / 10 min
// break, 10 min buffer after commitments, 25 min minimum chunk.
const defaults = Settings();

/// A time on the test day, Monday Oct 26 2026.
DateTime t(int hour, [int minute = 0]) => DateTime(2026, 10, 26, hour, minute);

Task task(
  String title,
  int estimateMin, {
  int importance = Task.medium,
  int dueInDays = 1,
}) {
  return Task(
    id: title,
    title: title,
    dueDate: DateTime(2026, 10, 26 + dueInDays),
    importance: importance,
    estimateMin: estimateMin,
    createdAt: DateTime(2026, 10, 20),
  );
}

Commitment commitment(String title, DateTime start, DateTime end) =>
    Commitment(id: title, title: title, start: start, end: end);

PlanResult run({
  List<Task> tasks = const [],
  List<Commitment> commitments = const [],
  Settings settings = defaults,
  double velocity = 1.0,
  DateTime? now,
  List<PlannedBlock> keepBlocks = const [],
}) {
  return plan(
    tasks: tasks,
    commitments: commitments,
    settings: settings,
    appliedVelocity: velocity,
    now: now ?? t(12),
    keepBlocks: keepBlocks,
  );
}

List<PlannedBlock> ofType(PlanResult result, BlockType type) =>
    result.blocks.where((b) => b.type == type).toList();

/// "15:00-15:30 a" style summary, handy for comparing whole plans.
String describe(PlannedBlock b) {
  String hm(DateTime d) => '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  return '${hm(b.start)}-${hm(b.end)} ${b.title}';
}

/// Every break must sit directly between two task blocks: never first or
/// last, never next to a commitment.
void expectBreaksBetweenWork(PlanResult result) {
  final blocks = result.blocks;
  for (var i = 0; i < blocks.length; i++) {
    if (blocks[i].type != BlockType.breakTime) continue;
    final b = describe(blocks[i]);
    expect(i, greaterThan(0), reason: '$b is first');
    expect(i, lessThan(blocks.length - 1), reason: '$b is last');
    final before = blocks[i - 1];
    final after = blocks[i + 1];
    expect(before.type, BlockType.task, reason: '$b after ${describe(before)}');
    expect(after.type, BlockType.task, reason: '$b before ${describe(after)}');
    expect(before.end, blocks[i].start, reason: '$b not right after work');
    expect(after.start, blocks[i].end, reason: '$b not right before work');
  }
}

void main() {
  group('work window', () {
    test('empty day: tasks back-to-back from workStart, priority order', () {
      final result = run(
        tasks: [
          task('low', 10, importance: Task.low),
          task('high', 20, importance: Task.high),
          task('medium', 15),
        ],
      );
      expect(result.blocks.map(describe), [
        '15:00-15:20 high',
        '15:20-15:35 medium',
        '15:35-15:45 low',
      ]);
      expect(result.overflow, isEmpty);
    });

    test('now mid-window: nothing before now, rounded up to 5 minutes', () {
      final result = run(
        tasks: [task('a', 30)],
        now: DateTime(2026, 10, 26, 15, 7, 30),
      );
      expect(result.blocks.map(describe), ['15:10-15:40 a']);

      final onTheDot = run(tasks: [task('a', 30)], now: t(16, 5));
      expect(onTheDot.blocks.single.start, t(16, 5));

      final withSeconds = run(
        tasks: [task('a', 30)],
        now: DateTime(2026, 10, 26, 16, 5, 1),
      );
      expect(withSeconds.blocks.single.start, t(16, 10));
    });

    test('now after workEnd: everything overflows', () {
      final result = run(
        tasks: [task('a', 30), task('b', 45)],
        commitments: [commitment('Practice', t(16), t(17))],
        now: t(22, 30),
      );
      expect(ofType(result, BlockType.task), isEmpty);
      // Commitments still show on the timeline.
      expect(ofType(result, BlockType.commitment), hasLength(1));
      // Same score, so the shorter task comes first.
      expect(result.overflow.map((o) => o.taskId), ['a', 'b']);
      expect(result.overflow.map((o) => o.remainingMinutes), [30, 45]);
    });
  });

  group('commitments', () {
    test('tasks go around a commitment, respecting the buffer', () {
      final result = run(
        tasks: [
          task('a', 45, importance: Task.high),
          task('b', 30),
        ],
        commitments: [commitment('Practice', t(16), t(17))],
      );
      expect(result.blocks.map(describe), [
        '15:00-15:45 a',
        '16:00-17:00 Practice',
        // 15 free minutes before practice is too short; 10 min buffer after.
        '17:10-17:40 b',
      ]);
    });

    test('overlapping commitments merge into one busy period', () {
      final result = run(
        tasks: [
          task('a', 45, importance: Task.high),
          task('b', 30),
        ],
        commitments: [
          commitment('Club', t(16), t(17)),
          commitment('Tutoring', t(16, 30), t(17, 30)),
        ],
      );
      final tasks = ofType(result, BlockType.task).map(describe);
      // Busy 4:00 - 5:40 (5:30 end + 10 min buffer).
      expect(tasks, ['15:00-15:45 a', '17:40-18:10 b']);
      expect(ofType(result, BlockType.commitment), hasLength(2));
    });

    test('commitments keep their real times, gaps round to 5 minutes', () {
      final result = run(
        tasks: [
          task('a', 30, importance: Task.high),
          task('b', 30),
        ],
        commitments: [commitment('Dentist', t(15, 32), t(16, 13))],
      );
      // Busy 3:32 - 4:23 widens to 3:30 - 4:25.
      expect(result.blocks.map(describe), [
        '15:00-15:30 a',
        '15:32-16:13 Dentist',
        '16:25-16:55 b',
      ]);
    });

    test('commitments on other days are ignored', () {
      final result = run(
        tasks: [task('a', 30)],
        commitments: [
          commitment(
            'Tomorrow',
            DateTime(2026, 10, 27, 15),
            DateTime(2026, 10, 27, 18),
          ),
        ],
      );
      expect(result.blocks.map(describe), ['15:00-15:30 a']);
    });
  });

  group('pomodoro 50/10', () {
    test('90 min task -> 50 / break 10 / 40', () {
      final result = run(tasks: [task('Essay', 90)]);
      expect(result.blocks.map(describe), [
        '15:00-15:50 Essay (1/2)',
        '15:50-16:00 Break',
        '16:00-16:40 Essay (2/2)',
      ]);
      // Every segment points at the same task so logging covers all of it.
      final segments = ofType(result, BlockType.task);
      expect(segments.every((b) => b.taskId == 'Essay'), isTrue);
      expect(segments.every((b) => b.isChunk), isTrue);
      expect(ofType(result, BlockType.breakTime).single.taskId, isNull);
    });

    test('120 min task -> 50 / 10 / 50 / 10 / 20', () {
      final result = run(tasks: [task('Project', 120)]);
      expect(result.blocks.map(describe), [
        '15:00-15:50 Project (1/3)',
        '15:50-16:00 Break',
        '16:00-16:50 Project (2/3)',
        '16:50-17:00 Break',
        '17:00-17:20 Project (3/3)',
      ]);
    });

    test('55 min task -> one 55 min block (leftover under 10 attached)', () {
      final result = run(tasks: [task('Lab report', 55)]);
      expect(result.blocks.map(describe), ['15:00-15:55 Lab report']);
      expect(result.blocks.single.isChunk, isFalse);
    });

    test('30 min task then 40 min task -> break splits the second', () {
      final result = run(
        tasks: [
          task('A', 30, importance: Task.high),
          task('B', 40),
        ],
      );
      expect(result.blocks.map(describe), [
        '15:00-15:30 A',
        '15:30-15:50 B (1/2)',
        '15:50-16:00 Break',
        '16:00-16:20 B (2/2)',
      ]);
      expect(
        ofType(result, BlockType.task).where((b) => b.taskId == 'B'),
        hasLength(2),
      );
    });

    test('break comes early instead of a tiny piece of the next task', () {
      // After 45 min only 5 min of the pomodoro is left; don't start B with
      // a 5 min sliver.
      final result = run(
        tasks: [
          task('A', 45, importance: Task.high),
          task('B', 30),
        ],
      );
      expect(result.blocks.map(describe), [
        '15:00-15:45 A',
        '15:45-15:55 Break',
        '15:55-16:25 B',
      ]);
    });

    test('no break directly before or after a commitment', () {
      final result = run(
        tasks: [
          task('A', 50, importance: Task.high),
          task('B', 30),
        ],
        // Busy 3:50 - 4:40 with the buffer.
        commitments: [commitment('Practice', t(15, 50), t(16, 30))],
      );
      expect(result.blocks.map(describe), [
        '15:00-15:50 A',
        '15:50-16:30 Practice',
        '16:40-17:10 B',
      ]);
      expectBreaksBetweenWork(result);
    });

    test('no trailing break at the end of the work window', () {
      // Window 3:00 - 4:00. After A there's 10 min left, but B can't fit,
      // so no break is added there.
      final result = run(
        tasks: [
          task('A', 50, importance: Task.high),
          task('B', 30),
        ],
        settings: const Settings(workEndMinutes: 16 * 60),
      );
      expect(result.blocks.map(describe), ['15:00-15:50 A']);
      expect(result.overflow.single.taskId, 'B');
    });

    test('a task ending exactly at 50 min gets no break after it', () {
      final result = run(tasks: [task('A', 50)]);
      expect(result.blocks.map(describe), ['15:00-15:50 A']);
    });

    test('break counter resets after a commitment', () {
      // A uses 40 min, then a commitment. B starts a fresh pomodoro, so its
      // 40 min stay in one block instead of 10 / break / 30.
      final result = run(
        tasks: [
          task('A', 40, importance: Task.high),
          task('B', 40),
        ],
        commitments: [commitment('Snack', t(15, 40), t(16))],
      );
      expect(result.blocks.map(describe), [
        '15:00-15:40 A',
        '15:40-16:00 Snack',
        '16:10-16:50 B',
      ]);
    });

    test('break settings come from Settings', () {
      final result = run(
        tasks: [task('A', 60)],
        settings: const Settings(breakEveryMin: 25, breakLengthMin: 5),
      );
      expect(result.blocks.map(describe), [
        '15:00-15:25 A (1/3)',
        '15:25-15:30 Break',
        '15:30-15:55 A (2/3)',
        '15:55-16:00 Break',
        '16:00-16:10 A (3/3)',
      ]);
    });
  });

  group('splitting across gaps', () {
    // Gaps: 3:00-3:45 (45 min) and 5:00-6:00 (60 min).
    const shortDay = Settings(workEndMinutes: 18 * 60);
    final practice = commitment('Practice', t(15, 45), t(16, 50));

    test('task bigger than any gap splits into labelled chunks', () {
      final result = run(
        tasks: [task('Essay', 120)],
        commitments: [practice],
        settings: shortDay,
      );
      final chunks = ofType(result, BlockType.task);
      // 60 min wouldn't fit in the second gap (50 + break + 10 = 70), but
      // 55 does (50 + 5 attached).
      expect(chunks.map(describe), [
        '15:00-15:45 Essay (1/2)',
        '17:00-17:55 Essay (2/2)',
      ]);
      expect(chunks.every((b) => b.isChunk && b.taskId == 'Essay'), isTrue);
      expect(result.overflow.single.taskId, 'Essay');
      expect(result.overflow.single.remainingMinutes, 20);
    });

    test('pieces smaller than minChunkMin are not scheduled', () {
      // Gaps: 45 min, then only 20 min (under the 25 min minimum).
      final result = run(
        tasks: [task('Essay', 60)],
        commitments: [practice],
        settings: const Settings(workEndMinutes: 17 * 60 + 20),
      );
      expect(ofType(result, BlockType.task).map(describe), [
        '15:00-15:45 Essay (part 1)',
      ]);
      expect(result.overflow.single.remainingMinutes, 15);
    });

    test('a task that fits whole is not split', () {
      final result = run(
        tasks: [task('Essay', 55)],
        commitments: [practice],
        settings: shortDay,
      );
      final block = ofType(result, BlockType.task).single;
      expect(describe(block), '17:00-17:55 Essay');
      expect(block.isChunk, isFalse);
    });
  });

  group('velocity', () {
    test('30 min at 1.4x = 42 min, rounded up to a 45 min block', () {
      final result = run(tasks: [task('a', 30)], velocity: 1.4);
      expect(result.blocks.map(describe), ['15:00-15:45 a']);
    });

    test('overflow minutes include velocity', () {
      final result = run(tasks: [task('a', 30)], velocity: 1.4, now: t(23));
      expect(result.overflow.single.remainingMinutes, 45);
    });
  });

  group('loggedMin', () {
    Task partlyDone(int loggedMin) => Task(
      id: 'Essay',
      title: 'Essay',
      dueDate: DateTime(2026, 10, 27),
      importance: Task.medium,
      estimateMin: 90,
      createdAt: DateTime(2026, 10, 20),
      loggedMin: loggedMin,
    );

    test('only the remaining minutes are scheduled', () {
      final result = run(tasks: [partlyDone(50)]);
      expect(result.blocks.map(describe), ['15:00-15:40 Essay']);
    });

    test('remaining time includes velocity, rounded up to 5', () {
      // 90 * 1.2 = 108, minus 50 logged = 58 -> 60: 50 / break / 10.
      final result = run(tasks: [partlyDone(50)], velocity: 1.2);
      expect(result.blocks.map(describe), [
        '15:00-15:50 Essay (1/2)',
        '15:50-16:00 Break',
        '16:00-16:10 Essay (2/2)',
      ]);
    });

    test('never less than 10 minutes, even if logged past the estimate', () {
      expect(run(tasks: [partlyDone(85)]).blocks.map(describe), [
        '15:00-15:10 Essay',
      ]);
      expect(run(tasks: [partlyDone(200)]).blocks.map(describe), [
        '15:00-15:10 Essay',
      ]);
    });

    test('overflow reports the remaining minutes', () {
      final result = run(tasks: [partlyDone(30)], now: t(23));
      expect(result.overflow.single.remainingMinutes, 60);
    });
  });

  group('overflow', () {
    test('isUrgent for due tomorrow or overdue, not next week', () {
      final result = run(
        tasks: [
          task('tomorrow', 30, dueInDays: 1),
          task('nextWeek', 30, dueInDays: 7),
          task('overdue', 30, dueInDays: -2),
          task('today', 30, dueInDays: 0),
        ],
        now: t(22, 30),
      );
      final urgent = {for (final o in result.overflow) o.taskId: o.isUrgent};
      expect(urgent, {
        'tomorrow': true,
        'nextWeek': false,
        'overdue': true,
        'today': true,
      });
    });
  });

  group('invariants', () {
    test('sorted, no overlaps, 5-minute boundaries, pomodoro limits', () {
      final result = run(
        tasks: [
          task('a', 25, importance: Task.high),
          task('b', 40),
          task('c', 90, importance: Task.low, dueInDays: 3),
          task('d', 60, dueInDays: 0),
          task('e', 15, dueInDays: -1),
          task('f', 120, importance: Task.high, dueInDays: 5),
          task('g', 35, importance: Task.low),
        ],
        commitments: [
          commitment('Club', t(15, 30), t(16, 10)),
          commitment('Dinner', t(18, 7), t(18, 52)),
        ],
        velocity: 1.3,
        now: DateTime(2026, 10, 26, 15, 3, 12),
      );

      expect(ofType(result, BlockType.task), isNotEmpty);
      expect(ofType(result, BlockType.breakTime), isNotEmpty);
      for (var i = 1; i < result.blocks.length; i++) {
        final prev = result.blocks[i - 1];
        final next = result.blocks[i];
        expect(
          prev.start.isAfter(next.start),
          isFalse,
          reason: 'sorted by start',
        );
        expect(
          prev.end.isAfter(next.start),
          isFalse,
          reason: '${describe(prev)} overlaps ${describe(next)}',
        );
      }
      for (final b in result.blocks) {
        if (b.type == BlockType.commitment) continue;
        expect(b.start.minute % 5, 0, reason: describe(b));
        expect(b.end.minute % 5, 0, reason: describe(b));
        expect(b.start.isBefore(t(15, 5)), isFalse, reason: describe(b));
        expect(b.end.isAfter(t(22)), isFalse, reason: describe(b));
      }
      for (final b in ofType(result, BlockType.breakTime)) {
        expect(b.end.difference(b.start).inMinutes, 10);
      }
      expectBreaksBetweenWork(result);

      // Continuous work (task blocks touching each other) never goes past
      // 59 min: 50 plus at most a 9 min leftover.
      var streak = 0;
      PlannedBlock? last;
      for (final b in result.blocks) {
        if (b.type != BlockType.task) {
          streak = 0;
          last = null;
          continue;
        }
        final length = b.end.difference(b.start).inMinutes;
        streak = last != null && last.end == b.start ? streak + length : length;
        expect(streak, lessThanOrEqualTo(59), reason: describe(b));
        last = b;
      }
    });
  });

  group('keepBlocks (re-plan)', () {
    test('kept blocks stay as-is and count as busy', () {
      final done = PlannedBlock(
        taskId: 'old',
        title: 'Old task',
        start: t(15),
        end: t(15, 30),
        type: BlockType.task,
        isDone: true,
      );
      final future = PlannedBlock(
        taskId: 'early',
        title: 'Finished early',
        start: t(16),
        end: t(16, 30),
        type: BlockType.task,
        isDone: true,
      );
      final result = run(
        tasks: [task('new', 30), task('next', 20, dueInDays: 2)],
        now: t(15, 40),
        keepBlocks: [done, future],
      );
      // Free: 3:40-4:00 (20 min) and 4:30 onward. 'new' needs 30 so it
      // goes after 4:30; the smaller 'next' fills the 20 min gap.
      expect(result.blocks.map(describe), [
        '15:00-15:30 Old task',
        '15:40-16:00 next',
        '16:00-16:30 Finished early',
        '16:30-17:00 new',
      ]);
      expect(result.blocks.first, same(done));
      expect(result.blocks[2], same(future));
    });

    test('commitment keepBlocks are not duplicated', () {
      final practice = commitment('Practice', t(16), t(17));
      final oldCommitmentBlock = PlannedBlock(
        title: 'Practice',
        start: t(16),
        end: t(17),
        type: BlockType.commitment,
      );
      final result = run(
        commitments: [practice],
        keepBlocks: [oldCommitmentBlock],
      );
      expect(ofType(result, BlockType.commitment), hasLength(1));
    });
  });

  test('demo: 90 min + 40 min tasks from 3:00 PM', () {
    final result = run(
      tasks: [
        task('Essay', 90, importance: Task.high),
        task('Math', 40),
      ],
    );
    expect(result.blocks.map(describe), [
      '15:00-15:50 Essay (1/2)',
      '15:50-16:00 Break',
      '16:00-16:40 Essay (2/2)',
      '16:40-16:50 Math (1/2)',
      '16:50-17:00 Break',
      '17:00-17:30 Math (2/2)',
    ]);
  });
}
