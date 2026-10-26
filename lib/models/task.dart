import 'package:uuid/uuid.dart';

import 'json_helpers.dart';

const _uuid = Uuid();

/// Something the user needs to get done.
class Task {
  /// dueDate is always stored as local midnight so day comparisons work.
  Task({
    required this.id,
    required this.title,
    required DateTime dueDate,
    required this.importance,
    required this.estimateMin,
    this.category,
    this.isDone = false,
    required this.createdAt,
    this.completedAt,
    this.loggedMin = 0,
  }) : dueDate = dateOnly(dueDate);

  /// Makes a brand new task with a fresh id and createdAt = now.
  static Task create({
    required String title,
    required DateTime dueDate,
    required int importance,
    required int estimateMin,
    String? category,
  }) {
    return Task(
      id: _uuid.v4(),
      title: title,
      dueDate: dueDate,
      importance: importance,
      estimateMin: estimateMin,
      category: category,
      createdAt: DateTime.now(),
    );
  }

  static const int low = 1;
  static const int medium = 2;
  static const int high = 3;

  final String id;
  final String title;
  final DateTime dueDate;

  /// 1 = Low, 2 = Medium, 3 = High.
  final int importance;
  final int estimateMin;
  final String? category;
  final bool isDone;
  final DateTime createdAt;
  final DateTime? completedAt;

  /// Minutes logged on this task so far (from finished timeline blocks).
  final int loggedMin;

  String get importanceLabel {
    switch (importance) {
      case low:
        return 'Low';
      case high:
        return 'High';
      default:
        return 'Medium';
    }
  }

  /// Use [clearCategory] / [clearCompletedAt] to set those fields back to null.
  Task copyWith({
    String? title,
    DateTime? dueDate,
    int? importance,
    int? estimateMin,
    String? category,
    bool clearCategory = false,
    bool? isDone,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    int? loggedMin,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      importance: importance ?? this.importance,
      estimateMin: estimateMin ?? this.estimateMin,
      category: clearCategory ? null : (category ?? this.category),
      isDone: isDone ?? this.isDone,
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      loggedMin: loggedMin ?? this.loggedMin,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dueDate': dueDate.toIso8601String(),
    'importance': importance,
    'estimateMin': estimateMin,
    'category': category,
    'isDone': isDone,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'loggedMin': loggedMin,
  };

  factory Task.fromJson(Map<String, dynamic> json) {
    final createdAt = readDate(json['createdAt']) ?? DateTime.now();
    return Task(
      id: readString(json['id'], ''),
      title: readString(json['title'], ''),
      dueDate: readDate(json['dueDate']) ?? createdAt,
      importance: readInt(json['importance'], medium).clamp(low, high),
      estimateMin: readInt(json['estimateMin'], 30),
      category: json['category'] as String?,
      isDone: readBool(json['isDone'], false),
      createdAt: createdAt,
      completedAt: readDate(json['completedAt']),
      loggedMin: readInt(json['loggedMin'], 0),
    );
  }

  @override
  bool operator ==(Object other) => other is Task && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
