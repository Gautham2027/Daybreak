import 'json_helpers.dart';
import 'overflow_item.dart';
import 'planned_block.dart';

/// A saved plan for one day: the timeline blocks plus the tasks that didn't
/// fit and spill over to tomorrow.
class PlanRecord {
  const PlanRecord({
    this.blocks = const [],
    this.overflow = const [],
    this.createdAt,
  });

  final List<PlannedBlock> blocks;
  final List<OverflowItem> overflow;

  /// When the plan was made. Null for plans saved before this was added.
  final DateTime? createdAt;

  List<String> get overflowTaskIds => overflow.map((o) => o.taskId).toList();

  PlanRecord copyWith({
    List<PlannedBlock>? blocks,
    List<OverflowItem>? overflow,
  }) {
    return PlanRecord(
      blocks: blocks ?? this.blocks,
      overflow: overflow ?? this.overflow,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'blocks': blocks.map((b) => b.toJson()).toList(),
    'overflow': overflow.map((o) => o.toJson()).toList(),
    'createdAt': createdAt?.toIso8601String(),
  };

  factory PlanRecord.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'];
    return PlanRecord(
      blocks: rawBlocks is List
          ? List.unmodifiable(
              rawBlocks.whereType<Map>().map(
                (b) => PlannedBlock.fromJson(Map<String, dynamic>.from(b)),
              ),
            )
          : const [],
      overflow: _readOverflow(json),
      createdAt: readDate(json['createdAt']),
    );
  }

  static List<OverflowItem> _readOverflow(Map<String, dynamic> json) {
    final raw = json['overflow'];
    if (raw is List) {
      return List.unmodifiable(
        raw.whereType<Map>().map(
          (o) => OverflowItem.fromJson(Map<String, dynamic>.from(o)),
        ),
      );
    }
    // Older saved plans only stored the task ids.
    final oldIds = json['overflowTaskIds'];
    if (oldIds is List) {
      return List.unmodifiable(
        oldIds.whereType<String>().map(
          (id) =>
              OverflowItem(taskId: id, remainingMinutes: 0, isUrgent: false),
        ),
      );
    }
    return const [];
  }
}
