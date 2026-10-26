import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/format.dart';
import '../services/scoring.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';

/// One task in the Tasks list: an importance-colored accent, a round
/// checkbox, the title, and one muted detail line
/// ("Due tomorrow · 45 min · Homework").
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.today,
    required this.onToggleDone,
    required this.onTap,
  });

  final Task task;
  final DateTime today;
  final VoidCallback onToggleDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = DaybreakColors.of(context);
    final accent = palette.importance(task.importance);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: '${task.importanceLabel} importance',
                child: Container(
                  width: 4,
                  color: task.isDone ? colors.outlineVariant : accent,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
                child: Center(
                  child: Checkbox(
                    value: task.isDone,
                    onChanged: (_) => onToggleDone(),
                    shape: const CircleBorder(),
                    side: BorderSide(color: accent, width: 2),
                    activeColor: palette.success,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    0,
                    Spacing.m,
                    Spacing.l,
                    Spacing.m,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 15,
                          decoration: task.isDone
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isDone ? colors.onSurfaceVariant : null,
                        ),
                      ),
                      const SizedBox(height: Spacing.xs),
                      _DetailLine(task: task, today: today),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Due tomorrow · 45 min · Homework · 25 min logged". Overdue is in the
/// error color and due-today in the accent color; the rest is muted.
class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.task, required this.today});

  final Task task;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final overdue = isOverdue(task.dueDate, today);
    final dueToday = !overdue && daysUntilDue(task.dueDate, today) == 0;

    final rest = [
      formatEstimate(task.estimateMin),
      if (task.category != null) task.category!,
      if (task.loggedMin > 0) '${formatEstimate(task.loggedMin)} logged',
    ].join(' · ');

    return Text.rich(
      TextSpan(
        style: theme.textTheme.labelMedium?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        children: [
          if (!task.isDone) ...[
            TextSpan(
              text: dueLabel(task.dueDate, today),
              style: TextStyle(
                color: overdue
                    ? colors.error
                    : dueToday
                    ? colors.primary
                    : null,
                fontWeight: overdue || dueToday ? FontWeight.w700 : null,
              ),
            ),
            const TextSpan(text: ' · '),
          ],
          TextSpan(text: rest),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Small pill showing Low / Medium / High in the importance color.
class ImportanceChip extends StatelessWidget {
  const ImportanceChip({super.key, required this.importance});

  final int importance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = DaybreakColors.of(context).importance(importance);
    final label = switch (importance) {
      Task.high => 'High',
      Task.low => 'Low',
      _ => 'Medium',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: Radii.chipRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
