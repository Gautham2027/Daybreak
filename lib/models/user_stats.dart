import 'json_helpers.dart';

/// The user's learned velocity, gamification progress, and the running
/// timer. Only one exists.
class UserStats {
  const UserStats({
    this.velocity = 1.0,
    this.logCount = 0,
    this.xp = 0,
    this.streak = 0,
    this.lastActiveDate,
    this.badges = const {},
    this.bestStreak = 0,
    this.accurateInARow = 0,
    this.runningTimerTaskId,
    this.runningTimerStartedAt,
    this.timerAccumulatedSec = 0,
  });

  /// Average of actual time / estimated time. 1.0 means estimates are spot on.
  final double velocity;
  final int logCount;
  final int xp;
  final int streak;
  final DateTime? lastActiveDate;

  /// Earned badges: name -> when it was earned.
  final Map<String, DateTime> badges;

  /// Longest streak ever.
  final int bestStreak;

  /// Accurate estimates in a row (for the Sharpshooter badge).
  final int accurateInARow;

  /// The task the timer belongs to, or null if no timer.
  final String? runningTimerTaskId;

  /// When the timer was last started. Null while paused.
  final DateTime? runningTimerStartedAt;

  /// Seconds counted before the last pause (so Pause/Resume works).
  final int timerAccumulatedSec;

  bool get hasTimer => runningTimerTaskId != null;
  bool get timerIsRunning => hasTimer && runningTimerStartedAt != null;

  /// Total time on the timer at [now].
  Duration timerElapsed(DateTime now) {
    if (!hasTimer) return Duration.zero;
    final running = runningTimerStartedAt == null
        ? Duration.zero
        : now.difference(runningTimerStartedAt!);
    return Duration(seconds: timerAccumulatedSec) + running;
  }

  /// Use [clearTimer] to remove the timer fields.
  UserStats copyWith({
    double? velocity,
    int? logCount,
    int? xp,
    int? streak,
    DateTime? lastActiveDate,
    Map<String, DateTime>? badges,
    int? bestStreak,
    int? accurateInARow,
    String? runningTimerTaskId,
    DateTime? runningTimerStartedAt,
    bool clearTimerStartedAt = false,
    int? timerAccumulatedSec,
    bool clearTimer = false,
  }) {
    return UserStats(
      velocity: velocity ?? this.velocity,
      logCount: logCount ?? this.logCount,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      badges: badges ?? this.badges,
      bestStreak: bestStreak ?? this.bestStreak,
      accurateInARow: accurateInARow ?? this.accurateInARow,
      runningTimerTaskId: clearTimer
          ? null
          : (runningTimerTaskId ?? this.runningTimerTaskId),
      runningTimerStartedAt: clearTimer || clearTimerStartedAt
          ? null
          : (runningTimerStartedAt ?? this.runningTimerStartedAt),
      timerAccumulatedSec: clearTimer
          ? 0
          : (timerAccumulatedSec ?? this.timerAccumulatedSec),
    );
  }

  Map<String, dynamic> toJson() => {
    'velocity': velocity,
    'logCount': logCount,
    'xp': xp,
    'streak': streak,
    'lastActiveDate': lastActiveDate?.toIso8601String(),
    'badges': {
      for (final entry in badges.entries)
        entry.key: entry.value.toIso8601String(),
    },
    'bestStreak': bestStreak,
    'accurateInARow': accurateInARow,
    'runningTimerTaskId': runningTimerTaskId,
    'runningTimerStartedAt': runningTimerStartedAt?.toIso8601String(),
    'timerAccumulatedSec': timerAccumulatedSec,
  };

  /// Badges are a map of name -> earned date. Older saves stored a plain
  /// list of names; those get the last active date (or now) as the date.
  static Map<String, DateTime> _readBadges(Object? raw, DateTime? fallback) {
    if (raw is Map) {
      return Map.unmodifiable({
        for (final entry in raw.entries)
          if (entry.key is String)
            entry.key as String:
                readDate(entry.value) ?? fallback ?? DateTime.now(),
      });
    }
    if (raw is List) {
      final date = fallback ?? DateTime.now();
      return Map.unmodifiable({
        for (final name in raw.whereType<String>()) name: date,
      });
    }
    return const {};
  }

  factory UserStats.fromJson(Map<String, dynamic> json) {
    final lastActive = readDate(json['lastActiveDate']);
    final streak = readInt(json['streak'], 0);
    final best = readInt(json['bestStreak'], 0);
    return UserStats(
      velocity: readDouble(json['velocity'], 1.0),
      logCount: readInt(json['logCount'], 0),
      xp: readInt(json['xp'], 0),
      streak: streak,
      lastActiveDate: lastActive,
      badges: _readBadges(json['badges'], lastActive),
      bestStreak: best > streak ? best : streak,
      accurateInARow: readInt(json['accurateInARow'], 0),
      runningTimerTaskId: json['runningTimerTaskId'] as String?,
      runningTimerStartedAt: readDate(json['runningTimerStartedAt']),
      timerAccumulatedSec: readInt(json['timerAccumulatedSec'], 0),
    );
  }
}
