import 'package:daybreak/models/commitment.dart';
import 'package:daybreak/models/plan_record.dart';
import 'package:daybreak/models/settings.dart';
import 'package:daybreak/models/task.dart';
import 'package:daybreak/models/time_log.dart';
import 'package:daybreak/models/user_stats.dart';
import 'package:daybreak/services/storage.dart';

/// A StorageService that keeps everything in plain maps. Widget tests use it
/// so they never touch Hive or real files.
class InMemoryStorage implements StorageService {
  InMemoryStorage({
    List<Task> tasks = const [],
    List<Commitment> commitments = const [],
    Settings settings = const Settings(),
  }) {
    _settings = settings;
    for (final task in tasks) {
      _tasks[task.id] = task;
    }
    for (final commitment in commitments) {
      _commitments[commitment.id] = commitment;
    }
  }

  final Map<String, Task> _tasks = {};
  final Map<String, Commitment> _commitments = {};
  final List<TimeLog> _logs = [];
  final Map<String, PlanRecord> _plans = {};
  UserStats _stats = const UserStats();
  late Settings _settings;

  @override
  Future<void> init() async {}

  @override
  List<Task> getAllTasks() =>
      _tasks.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Future<void> saveTask(Task task) async => _tasks[task.id] = task;

  @override
  Future<void> deleteTask(String id) async => _tasks.remove(id);

  @override
  List<Commitment> getAllCommitments() =>
      _commitments.values.toList()..sort((a, b) => a.start.compareTo(b.start));

  @override
  List<Commitment> getCommitmentsForDay(DateTime day) => getAllCommitments()
      .where(
        (c) =>
            c.start.year == day.year &&
            c.start.month == day.month &&
            c.start.day == day.day,
      )
      .toList();

  @override
  Future<void> saveCommitment(Commitment commitment) async =>
      _commitments[commitment.id] = commitment;

  @override
  Future<void> deleteCommitment(String id) async => _commitments.remove(id);

  @override
  List<TimeLog> getAllLogs() =>
      List.of(_logs)..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

  @override
  Future<void> addLog(TimeLog log) async => _logs.add(log);

  @override
  Future<void> deleteLog(String id) async =>
      _logs.removeWhere((l) => l.id == id);

  @override
  UserStats getStats() => _stats;

  @override
  Future<void> saveStats(UserStats stats) async => _stats = stats;

  @override
  Settings getSettings() => _settings;

  @override
  Future<void> saveSettings(Settings settings) async => _settings = settings;

  @override
  Future<void> savePlan(DateTime day, PlanRecord record) async =>
      _plans[StorageService.dayKey(day)] = record;

  @override
  PlanRecord? getPlan(DateTime day) => _plans[StorageService.dayKey(day)];

  @override
  Future<void> clearAll() async {
    _tasks.clear();
    _commitments.clear();
    _logs.clear();
    _plans.clear();
    _stats = const UserStats();
    _settings = const Settings();
  }
}
