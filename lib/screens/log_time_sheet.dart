import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/planned_block.dart';
import '../models/task.dart';
import '../providers/progress_controller.dart';
import '../providers/stats_provider.dart';
import '../providers/task_provider.dart';
import '../services/format.dart';
import '../services/gamification.dart';
import '../services/scoring.dart';
import '../widgets/minutes_input.dart';
import '../widgets/task_tile.dart';

/// What happened in the sheet, so the Today screen can react after it closes.
enum LogOutcome { logged, completed, notFinished }

class LogSheetResult {
  const LogSheetResult(this.outcome, {this.minutes = 0, this.completion});

  final LogOutcome outcome;
  final int minutes;

  /// Set when the task was completed, for the celebration.
  final CompletionResult? completion;
}

/// Bottom sheet for a task block: timer, minutes spent, and finishing.
class LogTimeSheet extends StatefulWidget {
  const LogTimeSheet({super.key, required this.block});

  final PlannedBlock block;

  @override
  State<LogTimeSheet> createState() => _LogTimeSheetState();
}

class _LogTimeSheetState extends State<LogTimeSheet> {
  late int _minutes;
  Timer? _ticker;
  bool _busy = false;

  PlannedBlock get block => widget.block;

  @override
  void initState() {
    super.initState();
    // Start from what was logged before, or the block's planned length.
    _minutes = block.actualMin ?? block.end.difference(block.start).inMinutes;
    // Redraw every second while a timer is running so the clock ticks.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && context.read<StatsProvider>().stats.timerIsRunning) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool _timerIsMine(StatsProvider stats) =>
      stats.stats.runningTimerTaskId == block.taskId;

  Future<void> _startTimer() async {
    final stats = context.read<StatsProvider>();
    final otherId = stats.stats.runningTimerTaskId;
    if (otherId != null && otherId != block.taskId) {
      final otherTitle =
          context.read<TaskProvider>().byId(otherId)?.title ?? 'another task';
      final elapsed = formatTimer(stats.stats.timerElapsed(DateTime.now()));
      final stop = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Stop the other timer?'),
          content: Text(
            'The timer for "$otherTitle" is at $elapsed. Only one timer can '
            'run at a time, and that time won\'t be logged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep it'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Stop & start here'),
            ),
          ],
        ),
      );
      if (stop != true) return;
      await stats.stopTimer(DateTime.now());
    }
    await stats.startTimer(block.taskId!, DateTime.now());
  }

  Future<void> _stopTimer() async {
    final minutes = await context.read<StatsProvider>().stopTimer(
      DateTime.now(),
    );
    setState(() => _minutes = minutes < 1 ? 1 : minutes);
  }

  /// The minutes to log: this task's timer if it's on, else the input.
  Future<int> _takeMinutes() async {
    final stats = context.read<StatsProvider>();
    if (_timerIsMine(stats)) {
      final fromTimer = await stats.stopTimer(DateTime.now());
      if (fromTimer > 0) return fromTimer;
    }
    return _minutes;
  }

  Future<void> _doneWithBlock() async {
    setState(() => _busy = true);
    final progress = context.read<ProgressController>();
    final tasks = context.read<TaskProvider>();
    final navigator = Navigator.of(context);

    final minutes = await _takeMinutes();
    final isLast = await progress.logBlock(block, minutes);
    if (!isLast) {
      navigator.pop(LogSheetResult(LogOutcome.logged, minutes: minutes));
      return;
    }

    final task = tasks.byId(block.taskId);
    if (task == null || !mounted) {
      navigator.pop(LogSheetResult(LogOutcome.logged, minutes: minutes));
      return;
    }
    final finished = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Did you finish the task?'),
        content: Text(
          'You\'ve logged ${formatEstimate(task.loggedMin)} on '
          '"${task.title}" (estimate: ${formatEstimate(task.estimateMin)}).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, done!'),
          ),
        ],
      ),
    );
    if (finished != true) {
      navigator.pop(const LogSheetResult(LogOutcome.notFinished));
      return;
    }
    final result = await progress.completeTask(
      task,
      task.loggedMin,
      DateTime.now(),
    );
    navigator.pop(LogSheetResult(LogOutcome.completed, completion: result));
  }

  /// Finished early: log this block, then complete the task with all the
  /// minutes logged so far. Its other blocks are marked done.
  Future<void> _finishedWholeTask() async {
    setState(() => _busy = true);
    final progress = context.read<ProgressController>();
    final tasks = context.read<TaskProvider>();
    final navigator = Navigator.of(context);

    if (!block.isDone) await progress.logBlock(block, await _takeMinutes());
    final task = tasks.byId(block.taskId);
    if (task == null) {
      navigator.pop();
      return;
    }
    final result = await progress.completeTask(
      task,
      task.loggedMin,
      DateTime.now(),
    );
    navigator.pop(LogSheetResult(LogOutcome.completed, completion: result));
  }

  @override
  Widget build(BuildContext context) {
    final task = context.watch<TaskProvider>().byId(block.taskId);
    final stats = context.watch<StatsProvider>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final plannedMin = block.end.difference(block.start).inMinutes;

    if (task == null) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('This task was deleted.'),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._taskDetails(task, plannedMin, today),
            const SizedBox(height: 20),
            if (block.isDone)
              _DoneSummary(
                loggedMin: block.actualMin,
                taskDone: task.isDone,
                busy: _busy,
                onFinishTask: _finishedWholeTask,
              )
            else
              ..._loggingControls(stats, now),
          ],
        ),
      ),
    );
  }

  /// Title, importance, due date, logged-so-far, and the block's time range.
  List<Widget> _taskDetails(Task task, int plannedMin, DateTime today) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return [
      Text(block.title, style: theme.textTheme.headlineSmall),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ImportanceChip(importance: task.importance),
          Text(
            dueLabel(task.dueDate, today),
            style: theme.textTheme.labelLarge?.copyWith(
              color: isOverdue(task.dueDate, today)
                  ? colors.error
                  : colors.onSurfaceVariant,
            ),
          ),
          if (task.loggedMin > 0)
            Text(
              '${formatEstimate(task.loggedMin)} logged so far',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Icon(Icons.schedule, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${formatTimeRange(block.start, block.end)}'
              ' · ${formatEstimate(plannedMin)}',
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    ];
  }

  /// Timer, minutes spent, and the two finish buttons.
  List<Widget> _loggingControls(StatsProvider stats, DateTime now) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return [
      _TimerCard(
        elapsed: _timerIsMine(stats)
            ? stats.stats.timerElapsed(now)
            : Duration.zero,
        isRunning: _timerIsMine(stats) && stats.stats.timerIsRunning,
        isPaused: _timerIsMine(stats) && !stats.stats.timerIsRunning,
        onStart: _busy ? null : _startTimer,
        onPause: () => stats.pauseTimer(DateTime.now()),
        onStop: _stopTimer,
      ),
      const SizedBox(height: 20),
      Text(
        'Minutes spent',
        textAlign: TextAlign.center,
        style: theme.textTheme.titleSmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      MinutesInput(
        value: _minutes,
        onChanged: (v) => setState(() => _minutes = v),
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: _busy ? null : _doneWithBlock,
        icon: const Icon(Icons.check),
        label: const Text('Done with this block'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy ? null : _finishedWholeTask,
        icon: const Icon(Icons.flag_outlined),
        label: const Text('Finished the whole task'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    ];
  }
}

/// Big m:ss clock with Start / Pause / Stop.
class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.elapsed,
    required this.isRunning,
    required this.isPaused,
    required this.onStart,
    required this.onPause,
    required this.onStop,
  });

  final Duration elapsed;
  final bool isRunning;
  final bool isPaused;
  final VoidCallback? onStart;
  final VoidCallback onPause;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(
              formatTimer(elapsed),
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isRunning ? colors.primary : colors.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isRunning)
                  FilledButton.tonalIcon(
                    onPressed: onPause,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(isPaused ? 'Resume' : 'Start'),
                  ),
                if (isRunning || isPaused) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: onStop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown for a block that's already logged.
class _DoneSummary extends StatelessWidget {
  const _DoneSummary({
    required this.loggedMin,
    required this.taskDone,
    required this.busy,
    required this.onFinishTask,
  });

  final int? loggedMin;
  final bool taskDone;
  final bool busy;
  final VoidCallback onFinishTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              loggedMin == null
                  ? 'Block done'
                  : 'Logged ${formatEstimate(loggedMin!)}',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
        if (!taskDone) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: busy ? null : onFinishTask,
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Finished the whole task'),
          ),
        ],
      ],
    );
  }
}
