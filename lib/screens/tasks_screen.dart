import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/progress_controller.dart';
import '../providers/task_provider.dart';
import '../services/format.dart';
import '../services/scoring.dart';
import '../theme/tokens.dart';
import '../widgets/celebration.dart';
import '../widgets/empty_state.dart';
import '../widgets/minutes_input.dart';
import '../widgets/task_tile.dart';
import 'task_form_screen.dart';

/// All tasks: open ones grouped by when they're due (Overdue, Today,
/// Tomorrow, This week, Later) and priority-sorted inside each group, with
/// completed ones tucked below.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  /// The "Add task" label shows at the top and collapses to + on scroll.
  bool _fabExtended = true;

  void _openForm(BuildContext context, {Task? task}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => TaskFormScreen(task: task),
      ),
    );
  }

  void _delete(BuildContext context, Task task) {
    final provider = context.read<TaskProvider>();
    provider.deleteTask(task.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Task deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => provider.addTask(task),
          ),
        ),
      );
  }

  /// Checking asks how long it took, then completes the task (with XP).
  /// Unchecking undoes the completion.
  Future<void> _toggleDone(BuildContext context, Task task) async {
    final progress = context.read<ProgressController>();
    if (task.isDone) {
      await progress.undoCompletion(task);
      return;
    }
    final choice = await showDialog<_HowLong>(
      context: context,
      builder: (_) => _HowLongDialog(task: task),
    );
    if (choice == null) return;
    final result = await progress.completeTask(
      task,
      choice.minutes,
      DateTime.now(),
    );
    if (context.mounted) await celebrate(context, result);
  }

  Widget _buildTile(BuildContext context, Task task, DateTime today) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: const _DeleteBackground(),
      onDismissed: (_) => _delete(context, task),
      child: TaskTile(
        task: task,
        today: today,
        onToggleDone: () => _toggleDone(context, task),
        onTap: () => _openForm(context, task: task),
      ),
    );
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final extended = n.metrics.pixels < 24;
    if (extended != _fabExtended) setState(() => _fabExtended = extended);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final today = DateTime.now();
    final open = sortByPriority(provider.openTasks, today);
    final done = provider.doneTasks
      ..sort(
        (a, b) => (b.completedAt ?? b.createdAt).compareTo(
          a.completedAt ?? a.createdAt,
        ),
      );

    // Group in priority order, so each group stays priority-sorted.
    final groups = <DueGroup, List<Task>>{};
    for (final task in open) {
      groups.putIfAbsent(dueGroupFor(task.dueDate, today), () => []).add(task);
    }

    Widget body;
    if (open.isEmpty && done.isEmpty) {
      body = const Center(
        child: EmptyState(
          icon: Icons.wb_twilight,
          title: 'No tasks yet',
          subtitle: 'Tap + to add your first task.',
        ),
      );
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ListView(
          // Bottom padding keeps the last card clear of the add button.
          padding: const EdgeInsets.only(top: Spacing.xs, bottom: 104),
          children: [
            if (open.isEmpty)
              const EmptyState(
                icon: Icons.celebration_outlined,
                title: 'All caught up',
                subtitle: 'Tap + to add another task.',
              ),
            for (final group in DueGroup.values)
              if (groups[group] case final tasks?) ...[
                _GroupHeader(group: group, count: tasks.length),
                for (final task in tasks) _buildTile(context, task, today),
              ],
            if (done.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.s),
                child: ExpansionTile(
                  title: Text('Completed (${done.length})'),
                  children: [
                    for (final task in done) _buildTile(context, task, today),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        tooltip: 'Add task',
        isExtended: _fabExtended,
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
    );
  }
}

/// "OVERDUE · 2", "TODAY · 1"... Overdue uses the error color.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.count});

  final DueGroup group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.l + Spacing.xs,
        Spacing.l,
        Spacing.l,
        Spacing.xs,
      ),
      child: Text(
        '${group.label.toUpperCase()} · $count',
        style: theme.textTheme.labelMedium?.copyWith(
          color: group == DueGroup.overdue
              ? colors.error
              : colors.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Red area revealed while swiping a task to delete it.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.delete_outline, color: colors.onErrorContainer),
    );
  }
}

/// The answer from the "How long did it take?" dialog. Null minutes = Skip.
class _HowLong {
  const _HowLong(this.minutes);

  final int? minutes;
}

class _HowLongDialog extends StatefulWidget {
  const _HowLongDialog({required this.task});

  final Task task;

  @override
  State<_HowLongDialog> createState() => _HowLongDialogState();
}

class _HowLongDialogState extends State<_HowLongDialog> {
  late int _minutes = widget.task.loggedMin > 0
      ? widget.task.loggedMin
      : widget.task.estimateMin;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('How long did it take?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You estimated ${formatEstimate(widget.task.estimateMin)}.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          MinutesInput(
            value: _minutes,
            onChanged: (v) => setState(() => _minutes = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const _HowLong(null)),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_HowLong(_minutes)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
