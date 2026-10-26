import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/stats_provider.dart';
import '../providers/task_provider.dart';
import '../services/format.dart';

/// Plain-language explanation of velocity, with the last 5 time logs.
class VelocitySheet extends StatelessWidget {
  const VelocitySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final stats = context.watch<StatsProvider>();
    final tasks = context.watch<TaskProvider>();
    final recent = stats.logs.reversed.take(5).toList();
    final badge = stats.velocityBadge;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: colors.primary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your velocity',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                Text(
                  badge.value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(stats.velocityMessage, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              'Daybreak compares your estimates to how long tasks actually '
              'took and adjusts future plans. Recent tasks count the most, '
              'and a timer you forgot to stop won\'t throw it off.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text('Recent tasks', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Finish a task and log your time to see it here.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            for (final log in recent)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  tasks.byId(log.taskId)?.title ?? 'Deleted task',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Estimated ${formatEstimate(log.estimateMin)} · '
                  'Actual ${formatEstimate(log.actualMin)}',
                ),
                trailing: log.wasAccurate
                    ? Tooltip(
                        message: 'Accurate estimate',
                        child: Icon(Icons.check_circle, color: colors.primary),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
