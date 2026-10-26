import 'json_helpers.dart';

/// A task (or the rest of one) that didn't fit in today's plan.
class OverflowItem {
  const OverflowItem({
    required this.taskId,
    required this.remainingMinutes,
    required this.isUrgent,
  });

  final String taskId;

  /// Planned minutes that couldn't be scheduled today.
  final int remainingMinutes;

  /// True if the task is due tomorrow or earlier.
  final bool isUrgent;

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'remainingMinutes': remainingMinutes,
    'isUrgent': isUrgent,
  };

  factory OverflowItem.fromJson(Map<String, dynamic> json) {
    return OverflowItem(
      taskId: readString(json['taskId'], ''),
      remainingMinutes: readInt(json['remainingMinutes'], 0),
      isUrgent: readBool(json['isUrgent'], false),
    );
  }
}
