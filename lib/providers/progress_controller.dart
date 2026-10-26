import 'package:uuid/uuid.dart';

import '../models/planned_block.dart';
import '../models/task.dart';
import '../services/gamification.dart';
import 'plan_provider.dart';
import 'stats_provider.dart';
import 'task_provider.dart';

const _uuid = Uuid();

/// The one place that logs time and completes tasks. It coordinates the
/// task, plan, and stats providers; the math lives in gamification.dart.
class ProgressController {
  ProgressController({
    required this.tasks,
    required this.stats,
    required this.plan,
  });

  final TaskProvider tasks;
  final StatsProvider stats;
  final PlanProvider plan;

  /// Logs [minutes] on one timeline block: saves them on the block, adds
  /// them to the task's loggedMin, and marks the block done.
  /// Returns true if that was the task's last unfinished block.
  Future<bool> logBlock(PlannedBlock block, int minutes) async {
    final isLast = plan.isLastOpenBlock(block);
    final task = tasks.byId(block.taskId);
    await plan.withoutMarkingStale(() async {
      await plan.logBlock(block, minutes);
      if (task != null) {
        await tasks.updateTask(
          task.copyWith(loggedMin: task.loggedMin + minutes),
        );
      }
    });
    return isLast;
  }

  /// Completes [task]: logs the time (unless [actualMin] is null = skip),
  /// updates velocity, XP, streak and badges, marks the task done, and marks
  /// its remaining plan blocks done.
  Future<CompletionResult> completeTask(
    Task task,
    int? actualMin,
    DateTime now,
  ) async {
    final current = tasks.byId(task.id) ?? task;

    return plan.withoutMarkingStale(() async {
      final blocksAfter = await plan.markTaskBlocksDone(current.id);
      final update = applyCompletion(
        stats: stats.stats,
        logs: stats.logs,
        task: current,
        actualMin: actualMin,
        now: now,
        todayBlocks: blocksAfter,
        logId: _uuid.v4(),
      );
      var newStats = update.stats;
      if (newStats.runningTimerTaskId == current.id) {
        newStats = newStats.copyWith(clearTimer: true);
      }
      await stats.applyCompletion(newStats, update.log);
      await tasks.updateTask(current.copyWith(isDone: true, completedAt: now));
      return update.result;
    });
  }

  /// Reopens [task]: removes its time log, takes back the XP it gave, and
  /// recomputes velocity. Streak isn't touched.
  Future<void> undoCompletion(Task task) async {
    final log = lastLogFor(task.id, stats.logs);
    // A skipped completion has no log; it gave the base XP.
    final xpToRemove = log?.xpAwarded ?? baseXp(task);
    final remaining = stats.logs.where((l) => l.id != log?.id).toList();
    await stats.applyUndo(
      applyUndo(
        stats: stats.stats,
        remainingLogs: remaining,
        xpToRemove: xpToRemove,
      ),
      log,
    );
    final current = tasks.byId(task.id) ?? task;
    await tasks.updateTask(
      current.copyWith(isDone: false, clearCompletedAt: true),
    );
  }
}
