import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/json_helpers.dart';
import '../providers/plan_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/task_provider.dart';
import '../services/format.dart';
import '../services/gamification.dart';
import '../services/stats.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../widgets/celebration.dart';
import '../widgets/velocity_chart.dart';

/// Level, streak, estimation accuracy, this week's totals, and badges.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final statsProvider = context.watch<StatsProvider>();
    final tasks = context.watch<TaskProvider>().tasks;
    // Rebuild when today's plan changes (for the pomodoro count).
    context.watch<PlanProvider>();

    final now = DateTime.now();
    final today = dateOnly(now);
    final stats = statsProvider.stats;
    final logs = statsProvider.logs;
    final week = weeklySummary(
      tasks: tasks,
      logs: logs,
      weekPlans: statsProvider.plansForWeek(today),
      today: today,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.page,
          Spacing.s,
          Spacing.page,
          Spacing.xxl,
        ),
        children: [
          // Level and streak side by side, equal height.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _LevelCard(xp: stats.xp)),
                const SizedBox(width: Spacing.m),
                Expanded(
                  child: _StreakCard(
                    streak: statsProvider.displayedStreak(now),
                    best: stats.bestStreak,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.m),
          _EstimationCard(
            message: statsProvider.velocityMessage,
            accuracy: accuracyRate(logs),
            history: velocityHistory(logs),
          ),
          const SizedBox(height: Spacing.m),
          _WeekCard(week: week),
          const SizedBox(height: Spacing.xl),
          const _SectionTitle('Badges'),
          const SizedBox(height: Spacing.s),
          _BadgeGrid(earned: stats.badges),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium);
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = DaybreakColors.of(context).importanceMedium;
    final current = level(xp);
    final toNext = xpPerLevel - xp % xpPerLevel;

    return _StatTile(
      icon: Icons.star_rounded,
      color: accent,
      title: 'Level $current',
      subtitle: '$xp XP',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: Radii.chipRadius,
            child: LinearProgressIndicator(
              value: levelProgress(xp),
              minHeight: 8,
              color: accent,
            ),
          ),
          const SizedBox(height: Spacing.s),
          Text(
            '$toNext XP to Level ${current + 1}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.best});

  final int streak;
  final int best;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StatTile(
      icon: Icons.local_fire_department,
      color: DaybreakColors.of(context).importanceHigh,
      title: streak == 1 ? '1 day streak' : '$streak day streak',
      subtitle: 'Best: $best ${best == 1 ? 'day' : 'days'}',
      footer: Text(
        streak > 0 ? 'Keep it going today!' : 'Finish a task to start one.',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Icon in a tinted circle, a bold title, a muted subtitle, and a footer.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.footer,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: Spacing.m),
            Text(title, style: theme.textTheme.titleLarge),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            const SizedBox(height: Spacing.m),
            footer,
          ],
        ),
      ),
    );
  }
}

class _EstimationCard extends StatelessWidget {
  const _EstimationCard({
    required this.message,
    required this.accuracy,
    required this.history,
  });

  final String message;
  final double? accuracy;
  final List<VelocityPoint> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.l + Spacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: colors.primary),
                const SizedBox(width: 8),
                Text('Estimation', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 10),
            Text(message, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  accuracy == null ? '–' : '${(accuracy! * 100).round()}%',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'of estimates within 15%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (history.length < 2)
              Container(
                height: 120,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Finish a couple of tasks with logged time and your '
                  'velocity chart will show up here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            else ...[
              VelocityChart(values: [for (final p in history) p.velocity]),
              const SizedBox(height: 4),
              Text(
                'Velocity after each finished task, oldest to newest.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week});

  final WeekSummary week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.l + Spacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This week', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _WeekStat(
                    icon: Icons.task_alt,
                    value: '${week.tasksCompleted}',
                    label: 'tasks done',
                  ),
                ),
                Expanded(
                  child: _WeekStat(
                    icon: Icons.timer_outlined,
                    value: formatEstimate(week.focusMinutes),
                    label: 'focus time',
                  ),
                ),
                Expanded(
                  child: _WeekStat(
                    icon: Icons.local_cafe_outlined,
                    value: '${week.pomodoros}',
                    label: 'pomodoros',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekStat extends StatelessWidget {
  const _WeekStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.earned});

  final Map<String, DateTime> earned;

  @override
  Widget build(BuildContext context) {
    // Three tiles side by side; IntrinsicHeight keeps them the same height
    // while letting them grow with large text.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, badge) in allBadges.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _BadgeTile(name: badge, earnedAt: earned[badge]),
            ),
          ],
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.name, required this.earnedAt});

  final String name;
  final DateTime? earnedAt;

  /// Desaturates a widget (locked badges).
  static const ColorFilter _grayscale = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = DaybreakColors.of(context);
    final isEarned = earnedAt != null;

    final medal = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.importanceMedium, palette.importanceHigh],
        ),
      ),
      child: Icon(
        badgeIcons[name] ?? Icons.emoji_events,
        color: colors.onPrimary,
        size: 28,
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.m),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                isEarned
                    ? medal
                    : Opacity(
                        opacity: 0.45,
                        child: ColorFiltered(
                          colorFilter: _grayscale,
                          child: medal,
                        ),
                      ),
                if (!isEarned)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: colors.surfaceContainerHighest,
                      child: Icon(
                        Icons.lock,
                        size: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.s + 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                name,
                maxLines: 1,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isEarned ? colors.onSurface : colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Flexible(
              child: Text(
                isEarned
                    ? 'Earned ${DateFormat('MMM d').format(earnedAt!)}'
                    : badgeHints[name] ?? '',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isEarned ? palette.success : colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
