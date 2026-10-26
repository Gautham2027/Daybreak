import 'package:flutter/foundation.dart';

import '../models/json_helpers.dart';
import '../models/overflow_item.dart';
import '../models/plan_record.dart';
import '../models/planned_block.dart';
import '../services/calendar.dart';
import '../services/planner.dart' as planner;
import '../services/storage.dart';
import 'commitment_provider.dart';
import 'settings_provider.dart';
import 'stats_provider.dart';
import 'task_provider.dart';

/// Holds today's plan and runs the planner using data from the other
/// providers.
class PlanProvider extends ChangeNotifier {
  PlanProvider(
    this._storage, {
    required this.tasks,
    required this.commitments,
    required this.settings,
    required this.stats,
    this.calendar,
  }) {
    _planDay = dateOnly(DateTime.now());
    _todayPlan = _storage.getPlan(_planDay);
    // Any change to the planner's inputs makes the current plan stale.
    tasks.addListener(_onTasksChanged);
    commitments.addListener(_onInputsChanged);
    settings.addListener(_onInputsChanged);
  }

  final StorageService _storage;
  final TaskProvider tasks;
  final CommitmentProvider commitments;
  final SettingsProvider settings;
  final StatsProvider stats;

  /// Used to import calendar events right before planning (optional).
  final CalendarService? calendar;

  PlanRecord? _todayPlan;
  bool _isStale = false;

  /// The day [_todayPlan] belongs to.
  late DateTime _planDay;

  /// True while tasks are changed by following the plan (logging a block,
  /// completing a task), so that change doesn't mark the plan stale.
  bool _updatingTasks = false;

  bool get hasPlanForToday => _todayPlan != null;
  List<PlannedBlock> get todayBlocks => _todayPlan?.blocks ?? const [];
  List<OverflowItem> get overflowItems => _todayPlan?.overflow ?? const [];

  /// True if tasks, commitments, or settings changed after planning.
  bool get isStale => _isStale;

  /// The time planning should use: real [now], or today at workStart when
  /// demo mode is on.
  DateTime effectiveNow(DateTime now) {
    final s = settings.settings;
    if (!s.demoMode) return now;
    return DateTime(now.year, now.month, now.day, 0, s.workStartMinutes);
  }

  /// Plans the whole day from scratch.
  Future<void> planMyDay(DateTime now) async {
    await _autoImportCalendar();
    await _runPlanner(effectiveNow(now), keepBlocks: []);
  }

  /// Plans again from now, keeping blocks that are done or already over.
  /// Done tasks aren't scheduled again because only open tasks are used.
  Future<void> replan(DateTime now) async {
    await _autoImportCalendar();
    final planNow = effectiveNow(now);
    final keep = todayBlocks
        .where(
          (b) =>
              b.type != BlockType.commitment &&
              (b.isDone || !b.end.isAfter(planNow)),
        )
        .toList();
    await _runPlanner(planNow, keepBlocks: keep);
  }

  /// Quietly imports today's calendar events first, if that's turned on.
  /// Any problem is ignored: importing must never block planning.
  Future<void> _autoImportCalendar() async {
    final s = settings.settings;
    final cal = calendar;
    if (cal == null ||
        !cal.isSupported ||
        !s.autoImportBeforePlanning ||
        s.selectedCalendarIds.isEmpty) {
      return;
    }
    try {
      await commitments.importFromCalendar(cal, s, DateTime.now());
    } catch (_) {
      // Plan with the commitments we already have.
    }
  }

  /// True if every other block of [block]'s task is already done.
  bool isLastOpenBlock(PlannedBlock block) => todayBlocks
      .where((b) => b.taskId == block.taskId && !identical(b, block))
      .every((b) => b.isDone);

  /// Marks one block done and records the minutes logged for it.
  Future<void> logBlock(PlannedBlock block, int actualMin) async {
    final plan = _todayPlan;
    if (plan == null) return;
    final blocks = List.of(plan.blocks);
    final index = blocks.indexOf(block);
    if (index == -1) return;
    blocks[index] = block.copyWith(isDone: true, actualMin: actualMin);
    await _saveBlocks(blocks);
  }

  /// Marks every block of [taskId] done. Returns today's blocks after.
  Future<List<PlannedBlock>> markTaskBlocksDone(String taskId) async {
    final plan = _todayPlan;
    if (plan == null) return const [];
    final blocks = [
      for (final b in plan.blocks)
        b.taskId == taskId && !b.isDone ? b.copyWith(isDone: true) : b,
    ];
    await _saveBlocks(blocks);
    return blocks;
  }

  /// Runs [action] (which changes tasks) without marking the plan stale.
  /// Used when the change comes from following the plan itself.
  Future<T> withoutMarkingStale<T>(Future<T> Function() action) async {
    _updatingTasks = true;
    try {
      return await action();
    } finally {
      _updatingTasks = false;
    }
  }

  Future<void> _saveBlocks(List<PlannedBlock> blocks) async {
    _todayPlan = _todayPlan!.copyWith(blocks: blocks);
    notifyListeners();
    await _storage.savePlan(_planDay, _todayPlan!);
  }

  /// Re-reads today's plan from storage (used after "Reset all data").
  void reload() {
    _planDay = dateOnly(DateTime.now());
    _todayPlan = _storage.getPlan(_planDay);
    _isStale = false;
    notifyListeners();
  }

  /// Call when the app comes back to the foreground: if it's a new day,
  /// yesterday's plan and commitments are swapped for today's.
  void checkForNewDay(DateTime now) {
    if (dateOnly(now) == _planDay) return;
    commitments.reload();
    _planDay = dateOnly(now);
    _todayPlan = _storage.getPlan(_planDay);
    _isStale = false;
    notifyListeners();
  }

  /// A deleted task's blocks are removed from the plan right away (the plan
  /// is then marked stale so the freed time can be re-planned).
  void _onTasksChanged() {
    final plan = _todayPlan;
    var pruned = false;
    if (plan != null) {
      bool gone(String? id) => id != null && tasks.byId(id) == null;
      final hasGone =
          plan.blocks.any((b) => gone(b.taskId)) ||
          plan.overflow.any((o) => gone(o.taskId));
      if (hasGone) {
        _todayPlan = plan.copyWith(
          blocks: plan.blocks.where((b) => !gone(b.taskId)).toList(),
          overflow: plan.overflow.where((o) => !gone(o.taskId)).toList(),
        );
        _storage.savePlan(_planDay, _todayPlan!);
        pruned = true;
      }
    }
    _onInputsChanged();
    // Already-stale plans skip the notify above, but the blocks changed.
    if (pruned) notifyListeners();
  }

  void _onInputsChanged() {
    if (_updatingTasks || _todayPlan == null || _isStale) return;
    _isStale = true;
    notifyListeners();
  }

  Future<void> _runPlanner(
    DateTime now, {
    required List<PlannedBlock> keepBlocks,
  }) async {
    final result = planner.plan(
      tasks: tasks.openTasks,
      commitments: commitments.commitments,
      settings: settings.settings,
      appliedVelocity: stats.appliedVelocity,
      now: now,
      keepBlocks: keepBlocks,
    );
    _todayPlan = PlanRecord(
      blocks: result.blocks,
      overflow: result.overflow,
      createdAt: DateTime.now(),
    );
    _isStale = false;
    _planDay = dateOnly(now);
    notifyListeners();
    await _storage.savePlan(_planDay, _todayPlan!);
  }

  @override
  void dispose() {
    tasks.removeListener(_onTasksChanged);
    commitments.removeListener(_onInputsChanged);
    settings.removeListener(_onInputsChanged);
    super.dispose();
  }
}
