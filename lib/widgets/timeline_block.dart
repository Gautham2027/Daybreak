import 'package:flutter/material.dart';

import '../models/planned_block.dart';
import '../models/task.dart';
import '../services/format.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';

/// Timeline scale: how tall one minute is.
const double pixelsPerMinute = 1.2;

/// Shortest card for tasks and commitments, so two lines of text fit.
const double minBlockHeight = 68;

/// Breaks are a slim fixed pill.
const double breakHeight = 34;

/// Height of a block on the timeline: proportional to its length, but never
/// too short to read. Minimums grow with the phone's text size.
double blockHeight(PlannedBlock block, BuildContext context) {
  final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
  final grow = textScale > 1 ? textScale : 1.0;
  if (block.type == BlockType.breakTime) return breakHeight * grow;
  final minutes = block.end.difference(block.start).inMinutes;
  final height = minutes * pixelsPerMinute;
  final minimum = minBlockHeight * grow;
  return height < minimum ? minimum : height;
}

/// The rail dot color for a block (matches its card's accent).
Color railColorFor(BuildContext context, PlannedBlock block, Task? task) {
  final palette = DaybreakColors.of(context);
  return switch (block.type) {
    BlockType.task => palette.importance(task?.importance),
    BlockType.commitment => palette.commitment,
    BlockType.breakTime => palette.breakColor,
  };
}

/// One block on the Today timeline: a task, a commitment, or a break.
class TimelineBlock extends StatelessWidget {
  const TimelineBlock({
    super.key,
    required this.block,
    this.task,
    this.isCurrent = false,
    this.fromCalendar = false,
    this.onTap,
  });

  final PlannedBlock block;

  /// The task behind a task block (null for commitments, breaks, or a task
  /// that was deleted). Used for the importance color and category.
  final Task? task;

  /// True if this block is happening right now.
  final bool isCurrent;

  /// True for commitments imported from the phone calendar.
  final bool fromCalendar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = switch (block.type) {
      BlockType.task => _TaskCard(
        block: block,
        task: task,
        isCurrent: isCurrent,
      ),
      BlockType.commitment => _CommitmentCard(
        block: block,
        isCurrent: isCurrent,
        fromCalendar: fromCalendar,
      ),
      BlockType.breakTime => _BreakPill(block: block),
    };

    return SizedBox(
      height: blockHeight(block, context),
      child: AnimatedOpacity(
        opacity: block.isDone ? 0.55 : 1,
        duration: Motion.of(context, Motion.medium),
        child: GestureDetector(onTap: onTap, child: child),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.block,
    required this.task,
    required this.isCurrent,
  });

  final PlannedBlock block;
  final Task? task;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = DaybreakColors.of(context).importance(task?.importance);
    final minutes = block.end.difference(block.start).inMinutes;
    final category = task?.category;
    final (:title, :badge) = splitSegmentTitle(block.title);

    return _AccentCard(
      accent: accent,
      isCurrent: isCurrent,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          decoration: block.isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: Spacing.s - 2),
                      _Pill(text: badge, color: accent, filled: true),
                    ],
                  ],
                ),
                const SizedBox(height: Spacing.xs),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${formatTimeRange(block.start, block.end)}'
                        ' · ${formatEstimate(minutes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (category != null) ...[
                      const SizedBox(width: Spacing.s),
                      _Pill(text: category, color: colors.onSurfaceVariant),
                    ],
                  ],
                ),
              ],
            ),
          ),
          _StatusIcon(block: block, isCurrent: isCurrent, color: accent),
        ],
      ),
    );
  }
}

/// The check pops in when a block is finished; a play icon marks the
/// block happening now.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({
    required this.block,
    required this.isCurrent,
    required this.color,
  });

  final PlannedBlock block;
  final bool isCurrent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final success = DaybreakColors.of(context).success;
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.slow),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: child,
      ),
      child: block.isDone
          ? Icon(
              Icons.check_circle,
              key: const ValueKey('done'),
              color: success,
            )
          : isCurrent
          ? Icon(
              Icons.play_circle_fill,
              key: const ValueKey('now'),
              color: color,
            )
          : const SizedBox.shrink(key: ValueKey('none')),
    );
  }
}

class _CommitmentCard extends StatelessWidget {
  const _CommitmentCard({
    required this.block,
    required this.isCurrent,
    required this.fromCalendar,
  });

  final PlannedBlock block;
  final bool isCurrent;
  final bool fromCalendar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = DaybreakColors.of(context).commitment;

    return _AccentCard(
      accent: accent,
      isCurrent: isCurrent,
      tint: 0.10,
      showBar: false,
      child: Row(
        children: [
          _IconCircle(icon: Icons.event, color: accent),
          const SizedBox(width: Spacing.m),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  formatTimeRange(block.start, block.end),
                  maxLines: 1,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (fromCalendar)
            Tooltip(
              message: 'From your calendar',
              child: Icon(
                Icons.calendar_month,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// A slim, dashed pill: breaks should feel light.
class _BreakPill extends StatelessWidget {
  const _BreakPill({required this.block});

  final PlannedBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final dash = DaybreakColors.of(context).breakColor;
    final minutes = block.end.difference(block.start).inMinutes;

    return CustomPaint(
      painter: _DashedPillPainter(color: dash),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.m),
        child: Row(
          children: [
            Icon(Icons.coffee_outlined, size: 16, color: color),
            const SizedBox(width: Spacing.s),
            Flexible(
              child: Text(
                '$minutes min break',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedPillPainter extends CustomPainter {
  const _DashedPillPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.75);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(size.height)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPillPainter old) => old.color != color;
}

/// Card with a 4px accent bar on the left and a faint accent tint. The
/// block happening now gets an accent outline.
class _AccentCard extends StatelessWidget {
  const _AccentCard({
    required this.accent,
    required this.isCurrent,
    required this.child,
    this.tint = 0.07,
    this.showBar = true,
  });

  final Color accent;
  final bool isCurrent;
  final Widget child;
  final double tint;
  final bool showBar;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = Theme.of(context).cardTheme.color ?? colors.surface;
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withValues(alpha: tint), base),
        borderRadius: Radii.cardRadius,
        border: Border.all(
          color: isCurrent ? accent : colors.outlineVariant,
          width: isCurrent ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showBar) Container(width: 4, color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.m + 2,
                vertical: Spacing.s,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

/// Small rounded label: segment badges ("1/2") and categories.
class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, this.filled = false});

  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.16) : null,
        borderRadius: Radii.chipRadius,
        border: filled
            ? null
            : Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: theme.textTheme.labelSmall?.copyWith(
          color: filled ? theme.colorScheme.onSurface : color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The "now" marker: a thin accent line with a dot that pulses a few times
/// (then rests), so it draws the eye without constant motion.
class NowLine extends StatefulWidget {
  const NowLine({super.key});

  @override
  State<NowLine> createState() => _NowLineState();
}

class _NowLineState extends State<NowLine> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: Motion.pulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _pulse.value = 0;
    } else if (!_pulse.isAnimating && _pulse.value == 0) {
      _pulse.repeat(count: 4);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 14,
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = _pulse.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Expanding, fading halo.
                    Container(
                      width: 8 + 6 * t,
                      height: 8 + 6 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.35 * (1 - t)),
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(child: Container(height: 1.5, color: color)),
        ],
      ),
    );
  }
}
