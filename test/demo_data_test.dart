import 'package:daybreak/models/planned_block.dart';
import 'package:daybreak/services/demo_data.dart';
import 'package:daybreak/services/gamification.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/in_memory_storage.dart';
import 'fakes/test_app.dart';

void main() {
  final now = DateTime.now();

  test('demo data matches the spec', () {
    final demo = buildDemoData(now);
    final open = demo.tasks.where((t) => !t.isDone).toList();
    expect(open, hasLength(6));
    expect(
      open.map((t) => t.title),
      containsAll(['Calc problem set', 'Study for chem quiz', 'Clean room']),
    );
    expect(demo.commitments.map((c) => c.title), [
      'Soccer practice',
      'Club meeting',
    ]);
    expect(demo.logs.map((l) => (l.estimateMin, l.actualMin)), [
      (30, 42),
      (45, 60),
      (20, 26),
      (60, 75),
    ]);
    // Velocity is unlocked and comes from the real logs.
    expect(demo.stats.logCount, 4);
    expect(demo.stats.velocity, closeTo(1.23, 0.01));
    expect(level(demo.stats.xp), 2);
    expect(demo.stats.streak, 4);
    expect(demo.stats.bestStreak, 6);
    expect(demo.stats.badges.keys, [earlyBird]);
    expect(demo.settings.demoMode, isTrue);
    expect(demo.settings.hasOnboarded, isTrue);
    expect(
      displayedStreak(
        demo.stats.streak,
        demo.stats.lastActiveDate,
        DateTime(now.year, now.month, now.day),
      ),
      4,
    );
  });

  test('loading demo data gives a valid plan with no overlaps', () async {
    final storage = InMemoryStorage();
    await loadDemoData(storage, now);
    final providers = TestProviders(storage);
    expect(providers.tasks.openTasks, hasLength(6));
    expect(providers.commitments.commitments, hasLength(2));

    await providers.plan.planMyDay(now);
    final blocks = providers.plan.todayBlocks;
    expect(blocks.where((b) => b.type == BlockType.task), isNotEmpty);
    expect(blocks.where((b) => b.type == BlockType.commitment), hasLength(2));
    for (var i = 1; i < blocks.length; i++) {
      expect(
        blocks[i - 1].end.isAfter(blocks[i].start),
        isFalse,
        reason: '${blocks[i - 1].title} overlaps ${blocks[i].title}',
      );
    }
    // Overdue chem quiz is top priority, so it's first at 3:00 PM.
    final first = blocks.first;
    expect(first.title, 'Study for chem quiz');
    expect(first.start, DateTime(now.year, now.month, now.day, 15));
    // 30 min at ~1.23x -> 37 -> a 40 min block.
    expect(first.end.difference(first.start).inMinutes, 40);
  });
}
