import 'package:flutter/foundation.dart';

import '../models/json_helpers.dart';
import '../models/plan_record.dart';
import '../models/time_log.dart';
import '../models/user_stats.dart';
import '../services/gamification.dart' as game;
import '../services/stats.dart' as stats_math;
import '../services/storage.dart';
import '../services/velocity.dart' as velocity;

/// Velocity, XP, streak, badges, time logs, and the running timer.
class StatsProvider extends ChangeNotifier {
  StatsProvider(this._storage) {
    _stats = _storage.getStats();
    _logs = _storage.getAllLogs();
  }

  final StorageService _storage;
  late UserStats _stats;
  List<TimeLog> _logs = [];

  /// Re-reads stats and logs from storage.
  void reload() {
    _stats = _storage.getStats();
    _logs = _storage.getAllLogs();
    notifyListeners();
  }

  UserStats get stats => _stats;

  /// All time logs, oldest first.
  List<TimeLog> get logs => List.unmodifiable(_logs);

  /// The velocity the planner uses (1.0 until there are 3 valid logs).
  double get appliedVelocity =>
      velocity.appliedVelocity(_stats.velocity, _stats.logCount);

  String get velocityMessage =>
      velocity.velocityMessage(appliedVelocity, _stats.logCount);

  /// Short version for the Today header, like "1.4×" + "pace".
  ({String value, String label}) get velocityBadge =>
      velocity.velocityBadge(appliedVelocity, _stats.logCount);

  int get level => game.level(_stats.xp);
  double get levelProgress => game.levelProgress(_stats.xp);

  /// Streak to show today (0 if a whole day was missed).
  int displayedStreak(DateTime now) =>
      game.displayedStreak(_stats.streak, _stats.lastActiveDate, dateOnly(now));

  /// Saved plans for Monday - Sunday of this week (for the Stats screen).
  List<PlanRecord> plansForWeek(DateTime today) => [
    for (final day in stats_math.weekDays(today)) ?_storage.getPlan(day),
  ];

  /// Stores a log and recomputes velocity from every log.
  Future<void> addLog(TimeLog log) async {
    _logs.add(log);
    final result = velocity.computeFromLogs(_logs);
    _stats = _stats.copyWith(
      velocity: result.velocity,
      logCount: result.validLogCount,
    );
    notifyListeners();
    await _storage.addLog(log);
    await _storage.saveStats(_stats);
  }

  /// Saves stats worked out by gamification.dart, plus the new log if any.
  Future<void> applyCompletion(UserStats newStats, TimeLog? log) async {
    _stats = newStats;
    if (log != null) _logs.add(log);
    notifyListeners();
    if (log != null) await _storage.addLog(log);
    await _storage.saveStats(_stats);
  }

  /// Removes a log and saves the stats from gamification.applyUndo.
  Future<void> applyUndo(UserStats newStats, TimeLog? removedLog) async {
    _stats = newStats;
    if (removedLog != null) _logs.removeWhere((l) => l.id == removedLog.id);
    notifyListeners();
    if (removedLog != null) await _storage.deleteLog(removedLog.id);
    await _storage.saveStats(_stats);
  }

  Future<void> updateStats(UserStats stats) async {
    _stats = stats;
    notifyListeners();
    await _storage.saveStats(stats);
  }

  // ---------- Timer (saved in UserStats so it survives restarts) ----------

  /// Starts (or resumes) the timer for [taskId].
  Future<void> startTimer(String taskId, DateTime now) {
    final sameTask = _stats.runningTimerTaskId == taskId;
    return updateStats(
      _stats.copyWith(
        runningTimerTaskId: taskId,
        runningTimerStartedAt: now,
        timerAccumulatedSec: sameTask ? _stats.timerAccumulatedSec : 0,
      ),
    );
  }

  Future<void> pauseTimer(DateTime now) {
    if (!_stats.timerIsRunning) return Future.value();
    return updateStats(
      _stats.copyWith(
        timerAccumulatedSec: _stats.timerElapsed(now).inSeconds,
        clearTimerStartedAt: true,
      ),
    );
  }

  /// Stops and clears the timer. Returns the whole minutes on it.
  Future<int> stopTimer(DateTime now) async {
    final minutes = (_stats.timerElapsed(now).inSeconds / 60).round();
    await updateStats(_stats.copyWith(clearTimer: true));
    return minutes;
  }
}
