import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../models/commitment.dart';
import '../models/plan_record.dart';
import '../models/settings.dart';
import '../models/task.dart';
import '../models/time_log.dart';
import '../models/user_stats.dart';

/// Saves and loads everything on the device using Hive.
///
/// Every record is stored as a plain JSON map (no TypeAdapters). Reads are
/// synchronous because Hive keeps open boxes in memory; writes are async.
///
/// Call Hive.initFlutter() (app) or Hive.init(path) (tests) before [init].
class StorageService {
  /// Hive box names, one per kind of record.
  static const String tasksBoxName = 'tasks';
  static const String commitmentsBoxName = 'commitments';
  static const String timeLogsBoxName = 'time_logs';
  static const String statsBoxName = 'stats';
  static const String settingsBoxName = 'settings';
  static const String plansBoxName = 'plans';

  static const String _statsKey = 'user';
  static const String _settingsKey = 'settings';

  late Box _tasks;
  late Box _commitments;
  late Box _timeLogs;
  late Box _stats;
  late Box _settings;
  late Box _plans;

  /// Opens every box. Must finish before any other method is used.
  Future<void> init() async {
    _tasks = await Hive.openBox(tasksBoxName);
    _commitments = await Hive.openBox(commitmentsBoxName);
    _timeLogs = await Hive.openBox(timeLogsBoxName);
    _stats = await Hive.openBox(statsBoxName);
    _settings = await Hive.openBox(settingsBoxName);
    _plans = await Hive.openBox(plansBoxName);
  }

  // ---------- Tasks ----------

  /// All tasks, oldest first.
  List<Task> getAllTasks() {
    final tasks = _readAll(_tasks).map(Task.fromJson).toList();
    tasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return tasks;
  }

  /// Inserts a new task or replaces the one with the same id.
  Future<void> saveTask(Task task) => _tasks.put(task.id, task.toJson());

  /// Removes the task with [id] (no-op if it doesn't exist).
  Future<void> deleteTask(String id) => _tasks.delete(id);

  // ---------- Commitments ----------

  /// All commitments, sorted by start time.
  List<Commitment> getAllCommitments() {
    final commitments = _readAll(_commitments)
        .map(Commitment.fromJson)
        .toList();
    commitments.sort((a, b) => a.start.compareTo(b.start));
    return commitments;
  }

  /// Commitments that start on the same calendar day as [day].
  List<Commitment> getCommitmentsForDay(DateTime day) {
    return getAllCommitments()
        .where(
          (c) =>
              c.start.year == day.year &&
              c.start.month == day.month &&
              c.start.day == day.day,
        )
        .toList();
  }

  /// Inserts a new commitment or replaces the one with the same id.
  Future<void> saveCommitment(Commitment commitment) =>
      _commitments.put(commitment.id, commitment.toJson());

  /// Removes the commitment with [id].
  Future<void> deleteCommitment(String id) => _commitments.delete(id);

  // ---------- Time logs ----------

  /// All time logs, oldest first.
  List<TimeLog> getAllLogs() {
    final logs = _readAll(_timeLogs).map(TimeLog.fromJson).toList();
    logs.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return logs;
  }

  /// Saves a time log (one per completed task).
  Future<void> addLog(TimeLog log) => _timeLogs.put(log.id, log.toJson());

  /// Removes a time log (used when a completion is undone).
  Future<void> deleteLog(String id) => _timeLogs.delete(id);

  // ---------- Stats ----------

  /// The saved stats, or fresh defaults if nothing has been saved yet.
  UserStats getStats() {
    final raw = _stats.get(_statsKey);
    return raw is Map ? UserStats.fromJson(_toJsonMap(raw)) : const UserStats();
  }

  /// Saves the single UserStats record.
  Future<void> saveStats(UserStats stats) =>
      _stats.put(_statsKey, stats.toJson());

  // ---------- Settings ----------

  /// The saved settings, or defaults if nothing has been saved yet.
  Settings getSettings() {
    final raw = _settings.get(_settingsKey);
    return raw is Map ? Settings.fromJson(_toJsonMap(raw)) : const Settings();
  }

  /// Saves the single Settings record.
  Future<void> saveSettings(Settings settings) =>
      _settings.put(_settingsKey, settings.toJson());

  // ---------- Plans ----------

  /// Plans are keyed by date, like "2026-10-26".
  static String dayKey(DateTime day) => DateFormat('yyyy-MM-dd').format(day);

  /// Saves [record] as the plan for [day], replacing any earlier one.
  Future<void> savePlan(DateTime day, PlanRecord record) =>
      _plans.put(dayKey(day), record.toJson());

  /// The plan saved for [day], or null if there isn't one.
  PlanRecord? getPlan(DateTime day) {
    final raw = _plans.get(dayKey(day));
    return raw is Map ? PlanRecord.fromJson(_toJsonMap(raw)) : null;
  }

  // ---------- Reset ----------

  /// Wipes every box. Used by tests and the demo reset.
  Future<void> clearAll() async {
    for (final box in [
      _tasks,
      _commitments,
      _timeLogs,
      _stats,
      _settings,
      _plans,
    ]) {
      await box.clear();
    }
  }

  /// Every map stored in [box], converted to JSON maps. Skips anything that
  /// isn't a map so one bad record can't crash the app.
  List<Map<String, dynamic>> _readAll(Box box) =>
      box.values.whereType<Map>().map(_toJsonMap).toList();
}

/// Hive hands back `Map<dynamic, dynamic>` (and nested lists/maps of dynamic).
/// This converts the whole thing to `Map<String, dynamic>` for fromJson.
Map<String, dynamic> _toJsonMap(Map raw) =>
    raw.map((key, value) => MapEntry(key.toString(), _convertValue(value)));

dynamic _convertValue(dynamic value) {
  if (value is Map) return _toJsonMap(value);
  if (value is List) return value.map(_convertValue).toList();
  return value;
}
