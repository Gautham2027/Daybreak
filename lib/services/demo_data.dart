import '../models/commitment.dart';
import '../models/settings.dart';
import '../models/task.dart';
import '../models/time_log.dart';
import '../models/user_stats.dart';
import 'gamification.dart';
import 'storage.dart';
import 'velocity.dart';

// Demo data: a fake but realistic school week, used by "Load demo data" and
// the "Try with demo data" button. It uses the real models and the real
// velocity math so all the numbers on screen match up.

/// Everything "Load demo data" creates.
class DemoData {
  const DemoData({
    required this.tasks,
    required this.commitments,
    required this.logs,
    required this.stats,
    required this.settings,
  });

  final List<Task> tasks;
  final List<Commitment> commitments;
  final List<TimeLog> logs;
  final UserStats stats;
  final Settings settings;
}

/// Builds the demo data relative to [now]: due dates count from today,
/// commitments are today, and finished tasks are spread over the last few
/// days.
DemoData buildDemoData(DateTime now) {
  final week = _DemoWeek(now);
  final logs = week.logs();
  final today = week.today;

  // Velocity comes from the real logs so the header, Stats chart, and
  // planner all agree.
  final velocity = computeFromLogs(logs);
  final stats = UserStats(
    velocity: velocity.velocity,
    logCount: velocity.validLogCount,
    xp: _demoXp,
    streak: _demoStreak,
    bestStreak: _demoBestStreak,
    // Normally yesterday; today if a completion was moved to this morning
    // (see _DemoWeek.finishedAt).
    lastActiveDate: logs.last.loggedAt.isBefore(today)
        ? week.dayOffset(-1)
        : today,
    badges: {earlyBird: week.dayOffset(-3, 17, 30)},
  );

  return DemoData(
    tasks: [...week.openTasks(), ...week.finishedTasks()],
    commitments: week.commitments(),
    logs: logs,
    stats: stats,
    settings: const Settings(demoMode: true, hasOnboarded: true),
  );
}

/// Level 2 (200-399 XP).
const int _demoXp = 230;
const int _demoStreak = 4;
const int _demoBestStreak = 6;

/// A task finished earlier in the week, with how long it really took.
typedef _Finished = ({
  String id,
  String title,
  int est,
  int act,
  int daysAgo,
  int imp,
  String cat,
});

/// Each one ran long (velocity about 1.2x), so smart estimates are unlocked.
const List<_Finished> _finished = [
  (
    id: 'demo-done-1',
    title: 'Spanish vocab quiz prep',
    est: 30,
    act: 42,
    daysAgo: 4,
    imp: Task.medium,
    cat: 'Study',
  ),
  (
    id: 'demo-done-2',
    title: 'Physics lab report',
    est: 45,
    act: 60,
    daysAgo: 3,
    imp: Task.high,
    cat: 'Homework',
  ),
  (
    id: 'demo-done-3',
    title: 'Math worksheet',
    est: 20,
    act: 26,
    daysAgo: 2,
    imp: Task.medium,
    cat: 'Homework',
  ),
  (
    id: 'demo-done-4',
    title: 'Read ch. 6 for English',
    est: 60,
    act: 75,
    daysAgo: 1,
    imp: Task.medium,
    cat: 'Homework',
  ),
];

/// Dates for the demo week, all relative to "today".
class _DemoWeek {
  _DemoWeek(DateTime now) : today = DateTime(now.year, now.month, now.day);

  final DateTime today;

  /// [days] from today (negative = in the past), at [hour]:[minute].
  DateTime dayOffset(int days, [int hour = 0, int minute = 0]) =>
      DateTime(today.year, today.month, today.day + days, hour, minute);

  /// When finished task number [index] was completed: usually [daysAgo] at
  /// 5:30 PM. The two most recent are kept inside this week (Mon - Sun) so
  /// the Stats screen's "This week" isn't empty, even on a Monday (then
  /// they're early this morning).
  DateTime finishedAt(int daysAgo, int index) {
    final weekStart = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    final usual = dayOffset(-daysAgo, 17, 30);
    final keepInWeek = index >= _finished.length - 2;
    if (!keepInWeek || !usual.isBefore(weekStart)) return usual;
    return DateTime(today.year, today.month, today.day, 7, 30 * index);
  }

  List<Task> openTasks() {
    Task open(
      String id,
      String title,
      int importance,
      int estimateMin,
      int dueInDays,
      String category,
    ) => Task(
      id: id,
      title: title,
      dueDate: dayOffset(dueInDays),
      importance: importance,
      estimateMin: estimateMin,
      category: category,
      createdAt: dayOffset(-5, 18),
    );

    return [
      open('demo-calc', 'Calc problem set', Task.high, 45, 1, 'Homework'),
      open('demo-essay', 'History essay draft', Task.high, 90, 2, 'Homework'),
      open('demo-cad', 'Robotics CAD model', Task.medium, 60, 4, 'Project'),
      open('demo-chem', 'Study for chem quiz', Task.high, 30, -1, 'Study'),
      open('demo-clean', 'Clean room', Task.low, 20, 5, 'Chores'),
      open(
        'demo-english',
        'Read ch. 7 for English',
        Task.medium,
        40,
        3,
        'Homework',
      ),
    ];
  }

  List<Task> finishedTasks() => [
    for (final (i, f) in _finished.indexed)
      Task(
        id: f.id,
        title: f.title,
        dueDate: dayOffset(-f.daysAgo + 2),
        importance: f.imp,
        estimateMin: f.est,
        category: f.cat,
        isDone: true,
        createdAt: dayOffset(-f.daysAgo - 2, 16),
        completedAt: finishedAt(f.daysAgo, i),
        loggedMin: f.act,
      ),
  ];

  /// One log per finished task (oldest first).
  List<TimeLog> logs() => [
    for (final (i, f) in _finished.indexed)
      TimeLog(
        id: '${f.id}-log',
        taskId: f.id,
        estimateMin: f.est,
        actualMin: f.act,
        loggedAt: finishedAt(f.daysAgo, i),
        xpAwarded: xpPerImportance * f.imp,
        wasAccurate: isAccurate(f.est, f.act),
      ),
  ];

  List<Commitment> commitments() => [
    Commitment(
      id: 'demo-soccer',
      title: 'Soccer practice',
      start: dayOffset(0, 16),
      end: dayOffset(0, 17, 30),
    ),
    Commitment(
      id: 'demo-club',
      title: 'Club meeting',
      start: dayOffset(0, 19),
      end: dayOffset(0, 19, 30),
    ),
  ];
}

/// Replaces everything in [storage] with demo data.
Future<void> loadDemoData(StorageService storage, DateTime now) async {
  final demo = buildDemoData(now);
  await storage.clearAll();
  for (final task in demo.tasks) {
    await storage.saveTask(task);
  }
  for (final commitment in demo.commitments) {
    await storage.saveCommitment(commitment);
  }
  for (final log in demo.logs) {
    await storage.addLog(log);
  }
  await storage.saveStats(demo.stats);
  await storage.saveSettings(demo.settings);
}
