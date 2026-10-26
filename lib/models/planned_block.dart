import 'json_helpers.dart';

/// What kind of block sits on the Today timeline.
enum BlockType {
  task('task'),
  commitment('commitment'),
  // `break` is a Dart keyword, so the enum value is breakTime.
  breakTime('break');

  const BlockType(this.value);

  /// The string saved in storage.
  final String value;

  /// Unknown or missing values fall back to [task].
  static BlockType fromValue(Object? value) =>
      BlockType.values.firstWhere((t) => t.value == value, orElse: () => task);
}

/// One slot in today's schedule.
class PlannedBlock {
  const PlannedBlock({
    this.taskId,
    required this.title,
    required this.start,
    required this.end,
    required this.type,
    this.isChunk = false,
    this.isDone = false,
    this.actualMin,
  });

  /// Only set for task blocks.
  final String? taskId;
  final String title;
  final DateTime start;
  final DateTime end;
  final BlockType type;

  /// True if this is one piece of a task that was split across gaps.
  final bool isChunk;
  final bool isDone;

  /// Minutes the user logged for this block (null until logged).
  final int? actualMin;

  PlannedBlock copyWith({
    String? taskId,
    String? title,
    DateTime? start,
    DateTime? end,
    BlockType? type,
    bool? isChunk,
    bool? isDone,
    int? actualMin,
  }) {
    return PlannedBlock(
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      type: type ?? this.type,
      isChunk: isChunk ?? this.isChunk,
      isDone: isDone ?? this.isDone,
      actualMin: actualMin ?? this.actualMin,
    );
  }

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'type': type.value,
    'isChunk': isChunk,
    'isDone': isDone,
    'actualMin': actualMin,
  };

  factory PlannedBlock.fromJson(Map<String, dynamic> json) {
    final start = readDate(json['start']) ?? DateTime.now();
    return PlannedBlock(
      taskId: json['taskId'] as String?,
      title: readString(json['title'], ''),
      start: start,
      end: readDate(json['end']) ?? start,
      type: BlockType.fromValue(json['type']),
      isChunk: readBool(json['isChunk'], false),
      isDone: readBool(json['isDone'], false),
      actualMin: json['actualMin'] is num
          ? (json['actualMin'] as num).toInt()
          : null,
    );
  }
}
