import 'package:uuid/uuid.dart';

import 'json_helpers.dart';

const _uuid = Uuid();

/// A record of how long a task actually took compared to its estimate.
class TimeLog {
  const TimeLog({
    required this.id,
    required this.taskId,
    required this.estimateMin,
    required this.actualMin,
    required this.loggedAt,
    this.xpAwarded = 0,
    this.wasAccurate = false,
  });

  static TimeLog create({
    required String taskId,
    required int estimateMin,
    required int actualMin,
    int xpAwarded = 0,
    bool wasAccurate = false,
  }) {
    return TimeLog(
      id: _uuid.v4(),
      taskId: taskId,
      estimateMin: estimateMin,
      actualMin: actualMin,
      loggedAt: DateTime.now(),
      xpAwarded: xpAwarded,
      wasAccurate: wasAccurate,
    );
  }

  final String id;
  final String taskId;
  final int estimateMin;
  final int actualMin;
  final DateTime loggedAt;

  /// XP given when the task was completed (removed again on undo).
  final int xpAwarded;

  /// True if actual time was within 15% of the estimate.
  final bool wasAccurate;

  TimeLog copyWith({
    String? taskId,
    int? estimateMin,
    int? actualMin,
    DateTime? loggedAt,
    int? xpAwarded,
    bool? wasAccurate,
  }) {
    return TimeLog(
      id: id,
      taskId: taskId ?? this.taskId,
      estimateMin: estimateMin ?? this.estimateMin,
      actualMin: actualMin ?? this.actualMin,
      loggedAt: loggedAt ?? this.loggedAt,
      xpAwarded: xpAwarded ?? this.xpAwarded,
      wasAccurate: wasAccurate ?? this.wasAccurate,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'estimateMin': estimateMin,
    'actualMin': actualMin,
    'loggedAt': loggedAt.toIso8601String(),
    'xpAwarded': xpAwarded,
    'wasAccurate': wasAccurate,
  };

  factory TimeLog.fromJson(Map<String, dynamic> json) {
    return TimeLog(
      id: readString(json['id'], ''),
      taskId: readString(json['taskId'], ''),
      estimateMin: readInt(json['estimateMin'], 0),
      actualMin: readInt(json['actualMin'], 0),
      loggedAt: readDate(json['loggedAt']) ?? DateTime.now(),
      xpAwarded: readInt(json['xpAwarded'], 0),
      wasAccurate: readBool(json['wasAccurate'], false),
    );
  }

  @override
  bool operator ==(Object other) => other is TimeLog && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
