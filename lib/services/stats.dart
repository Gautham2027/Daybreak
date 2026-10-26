import '../models/plan_record.dart';
import '../models/planned_block.dart';
import '../models/task.dart';
import '../models/time_log.dart';
import 'gamification.dart';
import 'velocity.dart';

// Math for the Stats screen. `today` is passed in so it can be tested.

/// Share of logs (0.0 - 1.0) where actual time was within 15% of the
/// estimate. Null if there are no logs yet.
double? accuracyRate(List<TimeLog> logs) {
  final counted = logs.where((l) => l.estimateMin > 0).toList();
  if (counted.isEmpty) return null;
  final accurate = counted
      .where((l) => isAccurate(l.estimateMin, l.actualMin))
      .length;
  return accurate / counted.length;
}

/// One point on the velocity chart.
class VelocityPoint {
  const VelocityPoint(this.time, this.velocity);

  final DateTime time;
  final double velocity;
}

/// The running velocity after each valid log, oldest first (the same math
/// as velocity.dart, step by step).
List<VelocityPoint> velocityHistory(List<TimeLog> logs) {
  final sorted = List<TimeLog>.of(logs)
    ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
  var v = startingVelocity;
  final points = <VelocityPoint>[];
  for (final log in sorted) {
    final r = ratio(log);
    if (!isValidRatio(r)) continue;
    v = updateVelocity(v, r);
    points.add(VelocityPoint(log.loggedAt, v));
  }
  return points;
}

/// Monday of the week containing [today], at midnight.
DateTime weekStart(DateTime today) =>
    DateTime(today.year, today.month, today.day - (today.weekday - 1));

/// The 7 days (Mon - Sun) of the week containing [today].
List<DateTime> weekDays(DateTime today) {
  final monday = weekStart(today);
  return [
    for (var i = 0; i < 7; i++)
      DateTime(monday.year, monday.month, monday.day + i),
  ];
}

/// This week's totals for the Stats screen.
class WeekSummary {
  const WeekSummary({
    required this.tasksCompleted,
    required this.focusMinutes,
    required this.pomodoros,
  });

  /// Tasks finished Monday - Sunday of this week.
  final int tasksCompleted;

  /// Minutes logged on tasks completed this week.
  final int focusMinutes;

  /// Task blocks marked done in this week's plans.
  final int pomodoros;
}

/// Totals for Monday - Sunday of the week containing [today].
/// [weekPlans] are the saved plans for those days (missing days skipped).
WeekSummary weeklySummary({
  required List<Task> tasks,
  required List<TimeLog> logs,
  required List<PlanRecord> weekPlans,
  required DateTime today,
}) {
  final start = weekStart(today);
  final end = DateTime(start.year, start.month, start.day + 7);
  bool inWeek(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  return WeekSummary(
    tasksCompleted: tasks
        .where(
          (t) => t.isDone && t.completedAt != null && inWeek(t.completedAt!),
        )
        .length,
    focusMinutes: logs
        .where((l) => inWeek(l.loggedAt))
        .fold(0, (sum, l) => sum + l.actualMin),
    pomodoros: weekPlans
        .expand((p) => p.blocks)
        .where((b) => b.type == BlockType.task && b.isDone)
        .length,
  );
}
