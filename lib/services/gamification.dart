import '../models/json_helpers.dart';
import '../models/planned_block.dart';
import '../models/task.dart';
import '../models/time_log.dart';
import '../models/user_stats.dart';
import 'scoring.dart';
import 'velocity.dart';

// XP, levels, streaks, and badges.
//
// The point is to reward finishing your planned work and making good
// estimates, without ever punishing you. You never lose XP, except that
// undoing a completion takes back the XP it gave.
//
// - XP: 10 per importance level (Low 10, Medium 20, High 30), plus 15 bonus
//   XP if your time was within 15% of the estimate.
// - Level: every 200 XP is a new level.
// - Streak: days in a row where you finished at least one task.
// - Badges: Sharpshooter (5 accurate estimates in a row), Early Bird
//   (finished 2+ days early), Clean Slate (finished every task block in a
//   day's plan).

/// XP per importance level when a task is finished.
const int xpPerImportance = 10;

/// Bonus XP for an accurate estimate.
const int accuracyBonusXp = 15;

/// An estimate is "accurate" when actual time is within this many percent.
/// (Kept as a whole-number percent so exactly 15% always counts.)
const int accuracyThresholdPercent = 15;

/// XP needed for each level.
const int xpPerLevel = 200;

/// Accurate estimates in a row needed for Sharpshooter.
const int sharpshooterInARow = 5;

/// Days before the due date a task must be finished for Early Bird.
const int earlyBirdDaysEarly = 2;

/// Badge names (also the keys saved in UserStats.badges).
const String sharpshooter = 'Sharpshooter';
const String earlyBird = 'Early Bird';
const String cleanSlate = 'Clean Slate';

/// All badges, in the order the Stats screen shows them.
const List<String> allBadges = [sharpshooter, earlyBird, cleanSlate];

/// How to earn each badge (shown while it's locked).
const Map<String, String> badgeHints = {
  sharpshooter: 'Get 5 estimates in a row within 15%.',
  earlyBird: 'Finish a task 2 or more days before it\'s due.',
  cleanSlate: 'Finish every task block in a day\'s plan.',
};

/// One-line descriptions shown when a badge is earned.
const Map<String, String> badgeDescriptions = {
  sharpshooter: '5 accurate estimates in a row.',
  earlyBird: 'Finished a task 2+ days before it was due.',
  cleanSlate: 'Finished every task block in today\'s plan.',
};

/// True when [actualMin] is within 15% of [estimateMin] (either way).
/// Uses whole-number math, |actual - estimate| * 100 <= estimate * 15, so
/// exactly 15% always counts and floating-point rounding can't interfere.
bool isAccurate(int estimateMin, int actualMin) {
  if (estimateMin <= 0) return false;
  return (actualMin - estimateMin).abs() * 100 <=
      estimateMin * accuracyThresholdPercent;
}

/// XP for finishing a task without logging time: 10 per importance level.
int baseXp(Task task) => xpPerImportance * task.importance;

/// XP for finishing a task that took [actualMin]: 10 per importance level,
/// plus 15 if the estimate was accurate.
int xpForCompletion(Task task, int actualMin) =>
    baseXp(task) +
    (isAccurate(task.estimateMin, actualMin) ? accuracyBonusXp : 0);

/// Calendar days from [from] to [to], ignoring time of day.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Streak after finishing something [today].
/// Same day: unchanged. Day after the last one: +1. Otherwise: starts at 1.
int updateStreak(int streak, DateTime? lastActiveDate, DateTime today) {
  if (lastActiveDate == null) return 1;
  final days = _daysBetween(lastActiveDate, today);
  if (days <= 0) return streak;
  if (days == 1) return streak + 1;
  return 1;
}

/// The streak to show: 0 once a whole day has passed with nothing finished.
/// (The saved streak isn't touched until the next completion.)
int displayedStreak(int streak, DateTime? lastActiveDate, DateTime today) {
  if (lastActiveDate == null) return 0;
  return _daysBetween(lastActiveDate, today) > 1 ? 0 : streak;
}

/// The level for [xp]: 0-199 XP is Level 1, 200-399 is Level 2, and so on.
int level(int xp) => xp ~/ xpPerLevel + 1;

/// 0.0 to 1.0: how far through the current level.
double levelProgress(int xp) => (xp % xpPerLevel) / xpPerLevel;

/// Badges earned by this completion that the user doesn't have yet.
/// [stats] already includes this completion (like accurateInARow), and
/// [todayBlocks] already has the task's blocks marked done.
List<String> newBadges({
  required UserStats stats,
  required Task task,
  required DateTime completedAt,
  required List<PlannedBlock> todayBlocks,
}) {
  final earned = <String>[];
  if (stats.accurateInARow >= sharpshooterInARow) earned.add(sharpshooter);
  if (daysUntilDue(task.dueDate, completedAt) >= earlyBirdDaysEarly) {
    earned.add(earlyBird);
  }
  final taskBlocks = todayBlocks.where((b) => b.type == BlockType.task);
  if (taskBlocks.isNotEmpty && taskBlocks.every((b) => b.isDone)) {
    earned.add(cleanSlate);
  }
  return earned.where((b) => !stats.badges.containsKey(b)).toList();
}

/// What the UI needs to celebrate a completion.
class CompletionResult {
  const CompletionResult({
    required this.xpGained,
    required this.wasAccurate,
    required this.newBadges,
    required this.leveledUp,
    required this.newLevel,
    required this.totalXp,
  });

  /// XP this completion gave.
  final int xpGained;

  /// True if the time spent was within 15% of the estimate.
  final bool wasAccurate;

  /// Badges earned by this completion (usually none).
  final List<String> newBadges;

  /// True if this completion reached a new level.
  final bool leveledUp;

  /// The level after this completion.
  final int newLevel;

  /// Total XP after this completion.
  final int totalXp;
}

/// New stats (and the log to save, if any) after completing a task.
class CompletionUpdate {
  const CompletionUpdate({
    required this.stats,
    required this.log,
    required this.result,
  });

  final UserStats stats;

  /// Null when the user skipped logging time.
  final TimeLog? log;
  final CompletionResult result;
}

/// Works out everything that changes when [task] is completed: the time
/// log, velocity, XP, streak, accurate-in-a-row count, and badges. Pure:
/// the caller (ProgressController) saves the result.
///
/// [actualMin] null means "skip": base XP only, no log, velocity unchanged,
/// accurate streak unchanged. [logs] are the existing logs (before this one).
CompletionUpdate applyCompletion({
  required UserStats stats,
  required List<TimeLog> logs,
  required Task task,
  required int? actualMin,
  required DateTime now,
  required List<PlannedBlock> todayBlocks,
  required String logId,
}) {
  final accurate = actualMin != null && isAccurate(task.estimateMin, actualMin);
  final xp = actualMin == null
      ? baseXp(task)
      : xpForCompletion(task, actualMin);
  final log = actualMin == null
      ? null
      : _completionLog(logId, task, actualMin, now, xp, accurate);

  var updated = _withStreakAndXp(stats, xp, now);
  if (log != null) {
    final v = computeFromLogs([...logs, log]);
    updated = updated.copyWith(
      velocity: v.velocity,
      logCount: v.validLogCount,
      accurateInARow: accurate ? stats.accurateInARow + 1 : 0,
    );
  }

  final badges = newBadges(
    stats: updated,
    task: task,
    completedAt: now,
    todayBlocks: todayBlocks,
  );
  updated = updated.copyWith(
    badges: {...updated.badges, for (final b in badges) b: now},
  );

  return CompletionUpdate(
    stats: updated,
    log: log,
    result: CompletionResult(
      xpGained: xp,
      wasAccurate: accurate,
      newBadges: badges,
      leveledUp: level(updated.xp) > level(stats.xp),
      newLevel: level(updated.xp),
      totalXp: updated.xp,
    ),
  );
}

/// The time log for a completion. It stores the task's ORIGINAL estimate
/// (not the velocity-adjusted plan), so velocity measures the user's
/// guesses rather than Daybreak's own adjustments.
TimeLog _completionLog(
  String id,
  Task task,
  int actualMin,
  DateTime now,
  int xp,
  bool accurate,
) {
  return TimeLog(
    id: id,
    taskId: task.id,
    estimateMin: task.estimateMin,
    actualMin: actualMin,
    loggedAt: now,
    xpAwarded: xp,
    wasAccurate: accurate,
  );
}

/// [stats] plus [xp], with the streak, best streak, and last active day
/// updated for a completion at [now].
UserStats _withStreakAndXp(UserStats stats, int xp, DateTime now) {
  final today = dateOnly(now);
  final streak = updateStreak(stats.streak, stats.lastActiveDate, today);
  return stats.copyWith(
    xp: stats.xp + xp,
    streak: streak,
    bestStreak: streak > stats.bestStreak ? streak : stats.bestStreak,
    lastActiveDate: today,
  );
}

/// The most recent log for [taskId], or null.
TimeLog? lastLogFor(String taskId, List<TimeLog> logs) {
  TimeLog? found;
  for (final log in logs) {
    if (log.taskId != taskId) continue;
    if (found == null || log.loggedAt.isAfter(found.loggedAt)) found = log;
  }
  return found;
}

/// Stats after undoing a completion: takes back [xpToRemove] (never below
/// 0) and recomputes velocity from [remainingLogs]. Streak isn't touched.
UserStats applyUndo({
  required UserStats stats,
  required List<TimeLog> remainingLogs,
  required int xpToRemove,
}) {
  final v = computeFromLogs(remainingLogs);
  final xp = stats.xp - xpToRemove;
  return stats.copyWith(
    xp: xp < 0 ? 0 : xp,
    velocity: v.velocity,
    logCount: v.validLogCount,
  );
}
