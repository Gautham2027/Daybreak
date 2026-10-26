import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/gamification.dart';
import '../theme/tokens.dart';

/// Icons for each badge (the names and descriptions live in
/// gamification.dart).
const Map<String, IconData> badgeIcons = {
  sharpshooter: Icons.gps_fixed,
  earlyBird: Icons.wb_sunny_outlined,
  cleanSlate: Icons.auto_awesome,
};

/// XP SnackBar, then a quick dialog for a level up and for each new badge.
Future<void> celebrate(BuildContext context, CompletionResult result) async {
  HapticFeedback.lightImpact();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: _XpCountUp(
          xp: result.xpGained,
          suffix: result.wasAccurate ? ' · Accurate estimate!' : '',
        ),
        duration: const Duration(seconds: 3),
      ),
    );

  if (result.leveledUp && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (context) => _CelebrationDialog(
        icon: Icons.trending_up,
        title: 'Level ${result.newLevel}!',
        message:
            '${result.totalXp % xpPerLevel} / $xpPerLevel XP to the next '
            'level.',
        progress: levelProgress(result.totalXp),
      ),
    );
  }
  for (final badge in result.newBadges) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _CelebrationDialog(
        icon: badgeIcons[badge] ?? Icons.emoji_events_outlined,
        title: 'Badge earned: $badge',
        message: badgeDescriptions[badge] ?? '',
      ),
    );
  }
}

class _CelebrationDialog extends StatelessWidget {
  const _CelebrationDialog({
    required this.icon,
    required this.title,
    required this.message,
    this.progress,
  });

  final IconData icon;
  final String title;
  final String message;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AlertDialog(
      icon: CircleAvatar(
        radius: 32,
        backgroundColor: colors.primaryContainer,
        child: Icon(icon, size: 32, color: colors.onPrimaryContainer),
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (progress != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Nice!'),
        ),
      ],
      actionsAlignment: MainAxisAlignment.center,
    );
  }
}

/// "+45 XP" counting up from 0 (instant when reduce motion is on).
class _XpCountUp extends StatelessWidget {
  const _XpCountUp({required this.xp, required this.suffix});

  final int xp;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: xp),
      duration: Motion.of(context, const Duration(milliseconds: 700)),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Text('+$value XP$suffix'),
    );
  }
}
