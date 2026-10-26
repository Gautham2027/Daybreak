import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/overflow_item.dart';
import '../models/planned_block.dart';
import '../models/settings.dart';
import '../models/task.dart';
import '../providers/commitment_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/task_provider.dart';
import '../services/format.dart';
import '../services/velocity.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../widgets/celebration.dart';
import '../widgets/empty_state.dart';
import '../widgets/timeline_block.dart';
import '../widgets/velocity_sheet.dart';
import 'commitments_screen.dart';
import 'log_time_sheet.dart';

/// Timeline layout: time labels, then the rail (line + dots), then cards.
const double _timeColumnWidth = 58;
const double _railWidth = 22;
const double _railX = _timeColumnWidth + _railWidth / 2;

/// Home screen: greeting, stats, plan actions, and today's timeline.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, this.onShowTasks});

  /// Switches the app to the Tasks tab.
  final VoidCallback? onShowTasks;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  /// Rebuilds every minute so the "now" line moves.
  Timer? _clock;

  /// Attached to the current (or next) block so we can scroll to it.
  final _currentBlockKey = GlobalKey();
  bool _didAutoScroll = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      // Left open past midnight: swap in the new day's plan.
      context.read<PlanProvider>().checkForNewDay(DateTime.now());
      setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _scrollToCurrentBlock() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _currentBlockKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.3,
        duration: Motion.of(context, Motion.slow),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _planMyDay() async {
    HapticFeedback.lightImpact();
    await context.read<PlanProvider>().planMyDay(DateTime.now());
    _scrollToCurrentBlock();
  }

  Future<void> _replan() async {
    await context.read<PlanProvider>().replan(DateTime.now());
    _scrollToCurrentBlock();
  }

  void _openCommitments() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CommitmentsScreen()));
  }

  Future<void> _openBlock(PlannedBlock block) async {
    final result = await showModalBottomSheet<LogSheetResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LogTimeSheet(block: block),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    switch (result.outcome) {
      case LogOutcome.completed:
        await celebrate(context, result.completion!);
      case LogOutcome.logged:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Logged ${formatEstimate(result.minutes)}')),
          );
      case LogOutcome.notFinished:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('No problem. Re-plan to fit in the rest.'),
              action: SnackBarAction(label: 'Re-plan', onPressed: _replan),
            ),
          );
    }
  }

  /// Opens the sheet for the running timer's task (its first open block).
  void _openTimerTask(String taskId) {
    final block = context
        .read<PlanProvider>()
        .todayBlocks
        .where((b) => b.taskId == taskId && !b.isDone)
        .firstOrNull;
    if (block != null) _openBlock(block);
  }

  void _openVelocity() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const VelocitySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanProvider>();
    final tasks = context.watch<TaskProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    context.watch<CommitmentProvider>();
    context.watch<StatsProvider>();

    final realNow = DateTime.now();
    // In demo mode the timeline acts as if it's the start of the work window.
    final now = plan.effectiveNow(realNow);
    final openTasks = tasks.openTasks;

    if (!_didAutoScroll && plan.hasPlanForToday) {
      _didAutoScroll = true;
      _scrollToCurrentBlock();
    }

    final children = <Widget>[
      _Header(
        now: realNow,
        demoMode: settings.demoMode,
        onTapTimer: _openTimerTask,
      ),
      const SizedBox(height: Spacing.m),
      _StatsRow(onTapVelocity: _openVelocity),
      const SizedBox(height: Spacing.section),
      // Everything below the header: the plan card before planning, then
      // the plan itself. It fades in when the first plan appears.
      _FadeInOnSwitch(
        switchKey: ValueKey(plan.hasPlanForToday),
        children: plan.hasPlanForToday
            ? _withPlanSection(plan, tasks, settings, now)
            : _beforePlanSection(openTasks),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.page,
            Spacing.l,
            Spacing.page,
            Spacing.xl + Spacing.s,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  /// Before today has a plan: the "Plan my day" card, or a nudge to add
  /// tasks if there's nothing to plan.
  List<Widget> _beforePlanSection(List<Task> openTasks) {
    return [
      openTasks.isEmpty
          ? _NothingToDoCard(onShowTasks: widget.onShowTasks)
          : _PlanCard(onPlan: _planMyDay, onCommitments: _openCommitments),
    ];
  }

  /// After planning: actions, the stale banner, the timeline, and anything
  /// that didn't fit.
  List<Widget> _withPlanSection(
    PlanProvider plan,
    TaskProvider tasks,
    Settings settings,
    DateTime now,
  ) {
    final blocks = plan.todayBlocks;
    final hasTaskBlocks = blocks.any((b) => b.type == BlockType.task);
    final overflow = plan.overflowItems
        .where((o) => tasks.byId(o.taskId)?.isDone == false)
        .toList();

    return [
      _PlanActions(onReplan: _replan, onCommitments: _openCommitments),
      if (plan.isStale) ...[
        const SizedBox(height: Spacing.m),
        _StaleBanner(onReplan: _replan),
      ],
      const SizedBox(height: Spacing.section),
      if (!hasTaskBlocks) ...[
        if (overflow.isNotEmpty)
          _NoTimeCard(
            windowEnded: now.hour * 60 + now.minute >= settings.workEndMinutes,
            workStart: settings.workStartMinutes,
            workEnd: settings.workEndMinutes,
          )
        else if (tasks.openTasks.isEmpty)
          _NothingToDoCard(onShowTasks: widget.onShowTasks),
        const SizedBox(height: Spacing.section),
      ],
      if (blocks.isNotEmpty)
        _Timeline(
          blocks: blocks,
          now: now,
          taskFor: tasks.byId,
          isFromCalendar: (block) =>
              context.read<CommitmentProvider>().commitments.any(
                (c) =>
                    c.isFromCalendar &&
                    c.title == block.title &&
                    c.start == block.start,
              ),
          currentBlockKey: _currentBlockKey,
          onTapBlock: _openBlock,
        ),
      if (overflow.isNotEmpty) ...[
        const SizedBox(height: Spacing.xl + Spacing.xs),
        _OverflowSection(
          items: overflow,
          taskFor: tasks.byId,
          today: DateTime(now.year, now.month, now.day),
        ),
      ],
    ];
  }
}

/// Fades (and slightly slides) its children in when [switchKey] changes.
class _FadeInOnSwitch extends StatelessWidget {
  const _FadeInOnSwitch({required this.switchKey, required this.children});

  final Key switchKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.slow),
      switchInCurve: Curves.easeOutCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Column(
        key: switchKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

/// Greeting on a soft "dawn" gradient that follows the time of day:
/// peach in the morning, gold in the afternoon, dusk purple in the evening.
class _Header extends StatelessWidget {
  const _Header({
    required this.now,
    required this.demoMode,
    required this.onTapTimer,
  });

  final DateTime now;
  final bool demoMode;
  final void Function(String taskId) onTapTimer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = DaybreakColors.of(context);
    final onDawn = palette.onDawn;
    final timerTaskId = context.watch<StatsProvider>().stats.runningTimerTaskId;
    final isEvening = now.hour >= 17;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.dawnFor(now),
        ),
        borderRadius: BorderRadius.circular(Radii.sheet),
      ),
      padding: const EdgeInsets.fromLTRB(
        Spacing.xl - 4,
        Spacing.xl - 4,
        Spacing.l,
        Spacing.xl - 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greetingFor(now),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: onDawn,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatLongDate(now),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: onDawn.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: onDawn.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isEvening ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                  color: onDawn,
                ),
              ),
            ],
          ),
          if (demoMode || timerTaskId != null) ...[
            const SizedBox(height: Spacing.m),
            Wrap(
              spacing: Spacing.s,
              runSpacing: Spacing.s,
              children: [
                if (demoMode)
                  _DawnChip(icon: Icons.science_outlined, label: 'Demo mode'),
                if (timerTaskId != null)
                  _TimerChip(onTap: () => onTapTimer(timerTaskId)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A small translucent chip that sits on the dawn gradient.
class _DawnChip extends StatelessWidget {
  const _DawnChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onDawn = DaybreakColors.of(context).onDawn;
    return Material(
      color: onDawn.withValues(alpha: 0.10),
      borderRadius: Radii.chipRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.chipRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: onDawn),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: onDawn),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "⏱ Essay · 12:34" chip while a timer is running or paused.
class _TimerChip extends StatefulWidget {
  const _TimerChip({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_TimerChip> createState() => _TimerChipState();
}

class _TimerChipState extends State<_TimerChip> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsProvider>().stats;
    final title =
        context.watch<TaskProvider>().byId(stats.runningTimerTaskId)?.title ??
        'Timer';
    final running = stats.timerIsRunning;

    return _DawnChip(
      onTap: widget.onTap,
      icon: running ? Icons.timer_outlined : Icons.pause_circle_outline,
      label:
          '$title · ${formatTimer(stats.timerElapsed(DateTime.now()))}'
          '${running ? '' : ' (paused)'}',
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.onTapVelocity});

  final VoidCallback onTapVelocity;

  @override
  Widget build(BuildContext context) {
    final statsProvider = context.watch<StatsProvider>();
    final stats = statsProvider.stats;
    final velocity = statsProvider.velocityBadge;
    final palette = DaybreakColors.of(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.star_rounded,
              color: palette.importanceMedium,
              value: 'Lv ${statsProvider.level}',
              label: '${stats.xp} XP',
              progress: statsProvider.levelProgress,
            ),
          ),
          const SizedBox(width: Spacing.s + 2),
          Expanded(
            child: _StatCard(
              icon: Icons.local_fire_department,
              color: palette.importanceHigh,
              value: '${statsProvider.displayedStreak(DateTime.now())}',
              label: 'day streak',
            ),
          ),
          const SizedBox(width: Spacing.s + 2),
          Expanded(
            child: _StatCard(
              icon: Icons.speed,
              color: palette.importanceLow,
              value: velocity.value,
              label: velocity.label,
              onTap: onTapVelocity,
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon in a tinted circle (with an optional progress ring), a big number,
/// and a small muted label.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.progress,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  /// Optional thin ring around the icon (used for level progress).
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (progress != null)
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 2.5,
                              color: color,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        Icon(icon, size: 19, color: color),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(Icons.chevron_right, size: 18, color: colors.outline),
                ],
              ),
              const SizedBox(height: Spacing.s + 2),
              Text(
                value,
                maxLines: 1,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan actions
// ---------------------------------------------------------------------------

/// Big call-to-action shown before today has a plan.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.onPlan, required this.onCommitments});

  final VoidCallback onPlan;
  final VoidCallback onCommitments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final openTasks = context.watch<TaskProvider>().openTasks;
    final commitmentCount = context
        .watch<CommitmentProvider>()
        .commitments
        .length;
    final velocity = context.watch<StatsProvider>().appliedVelocity;
    final totalMinutes = openTasks.fold<int>(
      0,
      (sum, t) => sum + adjustedMinutes(t.estimateMin, velocity),
    );

    String plural(int n, String word) => n == 1 ? '1 $word' : '$n ${word}s';
    final summary = [
      plural(openTasks.length, 'task'),
      formatEstimate(totalMinutes),
      plural(commitmentCount, 'commitment'),
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.primaryContainer,
            colors.primaryContainer.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: Radii.cardRadius,
      ),
      padding: const EdgeInsets.all(Spacing.xl - 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wb_twilight, color: colors.primary),
              ),
              const SizedBox(width: Spacing.m + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to plan your day?',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xl - 4),
          FilledButton.icon(
            onPressed: onPlan,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Plan my day'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              textStyle: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          TextButton.icon(
            onPressed: onCommitments,
            icon: const Icon(Icons.event_outlined),
            label: const Text('Add commitments first'),
            style: TextButton.styleFrom(
              foregroundColor: colors.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanActions extends StatelessWidget {
  const _PlanActions({required this.onReplan, required this.onCommitments});

  final VoidCallback onReplan;
  final VoidCallback onCommitments;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: onReplan,
            icon: const Icon(Icons.refresh),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Re-plan'),
            ),
          ),
        ),
        const SizedBox(width: Spacing.m),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onCommitments,
            icon: const Icon(Icons.event_outlined),
            // Shrinks rather than breaking mid-word at large text sizes.
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Commitments'),
            ),
          ),
        ),
      ],
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.onReplan});

  final VoidCallback onReplan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.secondaryContainer,
      borderRadius: BorderRadius.circular(Radii.control),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Row(
          children: [
            Icon(Icons.update, size: 20, color: colors.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your tasks changed since you planned. Re-plan?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSecondaryContainer,
                ),
              ),
            ),
            TextButton(onPressed: onReplan, child: const Text('Re-plan')),
          ],
        ),
      ),
    );
  }
}

class _NothingToDoCard extends StatelessWidget {
  const _NothingToDoCard({this.onShowTasks});

  final VoidCallback? onShowTasks;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          const EmptyState(
            icon: Icons.task_alt,
            title: 'Nothing on your plate',
            subtitle:
                'Add a few tasks and Daybreak will fit them into your day.',
          ),
          if (onShowTasks != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xl),
              child: FilledButton.tonalIcon(
                onPressed: onShowTasks,
                icon: const Icon(Icons.add),
                label: const Text('Go to Tasks'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown when a plan exists but no task blocks fit today.
class _NoTimeCard extends StatelessWidget {
  const _NoTimeCard({
    required this.windowEnded,
    required this.workStart,
    required this.workEnd,
  });

  final bool windowEnded;
  final int workStart;
  final int workEnd;

  @override
  Widget build(BuildContext context) {
    final window =
        '${formatMinutesOfDay(workStart)} – ${formatMinutesOfDay(workEnd)}';
    return Card(
      margin: EdgeInsets.zero,
      child: windowEnded
          ? EmptyState(
              icon: Icons.nightlight_round,
              title: 'Your work window has ended for today',
              subtitle:
                  'You plan work from $window. Get some rest; these tasks '
                  'are first in line tomorrow. (Demo mode in Settings lets '
                  'you plan anyway.)',
            )
          : const EmptyState(
              icon: Icons.event_busy,
              title: 'No free time left today',
              subtitle: 'Your commitments fill the rest of your work window.',
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline
// ---------------------------------------------------------------------------

/// Today's blocks on a vertical rail. Rows fade in one after another the
/// first time the plan appears (skipped when reduce motion is on).
class _Timeline extends StatefulWidget {
  const _Timeline({
    required this.blocks,
    required this.now,
    required this.taskFor,
    required this.isFromCalendar,
    required this.currentBlockKey,
    required this.onTapBlock,
  });

  final List<PlannedBlock> blocks;
  final DateTime now;
  final Task? Function(String? id) taskFor;

  /// Whether a commitment block came from the phone calendar (matched back
  /// to its commitment by title and start time).
  final bool Function(PlannedBlock block) isFromCalendar;
  final GlobalKey currentBlockKey;
  final void Function(PlannedBlock block) onTapBlock;

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance.isAnimating || _entrance.value > 0) return;
    if (Motion.reduced(context)) {
      _entrance.value = 1;
      return;
    }
    final steps = widget.blocks.length.clamp(1, 12);
    _entrance.duration = Motion.slow + Motion.stagger * steps;
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  bool _isHappeningNow(PlannedBlock b) =>
      !widget.now.isBefore(b.start) && widget.now.isBefore(b.end);

  double _fraction(DateTime start, DateTime end) {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    return widget.now.difference(start).inSeconds / total;
  }

  /// Row [index] of [count] fades and slides in during its own slice.
  Widget _staggered(Widget child, int index, int count) {
    final start = count <= 1 ? 0.0 : (index / count) * 0.6;
    final curve = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, (start + 0.4).clamp(0, 1), curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blocks = widget.blocks;
    // Scroll target: the block happening now, or else the next one.
    var targetIndex = blocks.indexWhere(_isHappeningNow);
    if (targetIndex == -1) {
      targetIndex = blocks.indexWhere((b) => b.end.isAfter(widget.now));
    }

    final rows = <Widget>[];
    DateTime? latestEnd;
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (latestEnd != null && block.start.isAfter(latestEnd)) {
        rows.add(
          _FreeTime(start: latestEnd, end: block.start, now: widget.now),
        );
      } else if (i > 0) {
        rows.add(const _RailGap(height: 6));
      }

      final isNow = _isHappeningNow(block);
      final task = widget.taskFor(block.taskId);
      rows.add(
        _TimelineRow(
          key: i == targetIndex ? widget.currentBlockKey : null,
          block: block,
          task: task,
          isCurrent: isNow,
          fromCalendar:
              block.type == BlockType.commitment &&
              widget.isFromCalendar(block),
          nowFraction: isNow ? _fraction(block.start, block.end) : null,
          onTap: block.type == BlockType.task && task != null
              ? () => widget.onTapBlock(block)
              : null,
        ),
      );
      if (latestEnd == null || block.end.isAfter(latestEnd)) {
        latestEnd = block.end;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          _staggered(rows[i], i, rows.length),
      ],
    );
  }
}

/// The thin vertical rail line, drawn behind every row and gap.
class _RailLine extends StatelessWidget {
  const _RailLine();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _railX - 1,
      top: 0,
      bottom: 0,
      child: Container(
        width: 2,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

/// A short stretch of rail between back-to-back blocks.
class _RailGap extends StatelessWidget {
  const _RailGap({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Stack(children: [_RailLine()]),
    );
  }
}

/// A time label, a dot on the rail, and the block card.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    super.key,
    required this.block,
    required this.task,
    required this.isCurrent,
    required this.fromCalendar,
    required this.nowFraction,
    required this.onTap,
  });

  final PlannedBlock block;
  final Task? task;
  final bool isCurrent;
  final bool fromCalendar;

  /// Where the "now" line goes inside this block (0 = top, 1 = bottom).
  final double? nowFraction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isBreak = block.type == BlockType.breakTime;
    final height = blockHeight(block, context);
    final dotSize = isCurrent ? 14.0 : (isBreak ? 8.0 : 11.0);
    final dotTop = isBreak ? height / 2 - dotSize / 2 : 16 - dotSize / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const _RailLine(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _timeColumnWidth,
              child: Padding(
                padding: EdgeInsets.only(top: isBreak ? 9 : 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatTime(block.start),
                    maxLines: 1,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isCurrent
                          ? colors.onSurface
                          : colors.onSurfaceVariant.withValues(
                              alpha: isBreak ? 0.7 : 1,
                            ),
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: _railWidth),
            Expanded(
              child: TimelineBlock(
                block: block,
                task: task,
                isCurrent: isCurrent,
                fromCalendar: fromCalendar,
                onTap: onTap,
              ),
            ),
          ],
        ),
        // The block's dot on the rail (with a surface-colored ring so it
        // stands off the line).
        Positioned(
          left: _railX - dotSize / 2,
          top: dotTop,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: block.isDone
                  ? DaybreakColors.of(context).success
                  : railColorFor(context, block, task),
              shape: BoxShape.circle,
              border: Border.all(color: colors.surface, width: 2),
            ),
          ),
        ),
        if (nowFraction != null)
          Positioned(
            left: _railX - 7,
            right: 0,
            top: (nowFraction! * height) - 7,
            child: const IgnorePointer(child: NowLine()),
          ),
      ],
    );
  }
}

/// Free time between blocks. Long gaps are capped so the list stays tidy.
class _FreeTime extends StatelessWidget {
  const _FreeTime({required this.start, required this.end, required this.now});

  final DateTime start;
  final DateTime end;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = end.difference(start).inMinutes;
    final height = (minutes * pixelsPerMinute).clamp(14.0, 56.0);
    final nowInside = !now.isBefore(start) && now.isBefore(end);
    final fraction = nowInside
        ? now.difference(start).inSeconds / end.difference(start).inSeconds
        : 0.0;

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const _RailLine(),
          if (minutes >= 15)
            Padding(
              padding: const EdgeInsets.only(
                left: _timeColumnWidth + _railWidth + Spacing.xs,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${formatEstimate(minutes)} free',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
          if (nowInside)
            Positioned(
              left: _railX - 7,
              right: 0,
              top: fraction * height - 7,
              child: const NowLine(),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Didn't fit today
// ---------------------------------------------------------------------------

/// Collapsible list of what didn't fit, with a count badge.
class _OverflowSection extends StatefulWidget {
  const _OverflowSection({
    required this.items,
    required this.taskFor,
    required this.today,
  });

  final List<OverflowItem> items;
  final Task? Function(String? id) taskFor;
  final DateTime today;

  @override
  State<_OverflowSection> createState() => _OverflowSectionState();
}

class _OverflowSectionState extends State<_OverflowSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shown = [
      for (final item in widget.items)
        if (widget.taskFor(item.taskId) case final task?) (item, task),
    ];
    final anyUrgent = shown.any((e) => e.$1.isUrgent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(Radii.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.s),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    "Didn't fit today",
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: Spacing.s),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.s,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: anyUrgent
                        ? colors.errorContainer
                        : colors.surfaceContainerHighest,
                    borderRadius: Radii.chipRadius,
                  ),
                  child: Text(
                    '${shown.length}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: anyUrgent
                          ? colors.onErrorContainer
                          : colors.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: Motion.of(context, Motion.medium),
                  child: Icon(Icons.expand_more, color: colors.outline),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.medium),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_expanded
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final (item, task) in shown)
                            _OverflowTile(
                              item: item,
                              task: task,
                              today: widget.today,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.s),
                    Text(
                      'These will be first in line tomorrow.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _OverflowTile extends StatelessWidget {
  const _OverflowTile({
    required this.item,
    required this.task,
    required this.today,
  });

  final OverflowItem item;
  final Task task;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final minutes = item.remainingMinutes > 0
        ? item.remainingMinutes
        : task.estimateMin;
    return ListTile(
      leading: Icon(
        item.isUrgent ? Icons.warning_amber_rounded : Icons.schedule,
        color: item.isUrgent ? colors.error : colors.outline,
      ),
      title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text.rich(
        TextSpan(
          text: '${formatEstimate(minutes)} left',
          children: [
            if (item.isUrgent)
              TextSpan(
                text: ' · ${dueLabel(task.dueDate, today)}',
                style: TextStyle(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
