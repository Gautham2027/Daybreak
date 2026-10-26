import '../models/commitment.dart';
import '../models/overflow_item.dart';
import '../models/planned_block.dart';
import '../models/settings.dart';
import '../models/task.dart';
import 'scoring.dart';
import 'velocity.dart';

// Daily planner
//
// This is the main algorithm of the app. It takes today's open tasks and
// commitments and turns them into a schedule. The basic idea:
//
//   1. Figure out the work window (3 PM to 10 PM by default, or starting
//      from now if it's already later than that).
//   2. Block off commitments, plus a 10 min buffer after each one, to get
//      the free gaps.
//   3. Work out how long each task will really take: estimate x velocity,
//      minus any time already logged, rounded up to 5 minutes.
//   4. Go through the tasks from highest priority to lowest and put each one
//      in the first gap it fits in. If it doesn't fit anywhere, split it
//      across gaps (each piece has to be at least 25 min).
//   5. Work is broken into 50 min focus sessions with 10 min breaks, even
//      inside one long task. Breaks only go between two pieces of work, so
//      there's never a break right before a commitment or at the end of the
//      night.
//   6. Whatever still doesn't fit goes on the "Didn't fit today" list.
//
// Split tasks get labels like "Essay (1/2)" and every piece keeps the task's
// id, so logging time works on the whole task.
//
// All the times in here are minutes after midnight (900 = 3:00 PM) because
// that made the math way easier. They get turned back into DateTimes at the
// end.

/// Every block the planner creates lands on this grid (in minutes).
const int slotMinutes = 5;

/// Pieces of work shorter than this are merged into the previous piece.
const int minSegmentMin = 10;

/// A partly-logged task still gets at least this much time on re-plan.
const int minTaskMinutes = 10;

/// Overflow is "urgent" when the task is due within this many days
/// (0 = today or overdue, 1 = tomorrow).
const int urgentWithinDays = 1;

const int _minutesPerDay = 24 * 60;

/// What the planner returns: the timeline plus what didn't fit.
class PlanResult {
  const PlanResult({required this.blocks, required this.overflow});

  /// Commitments, task blocks, and breaks, sorted by start time.
  final List<PlannedBlock> blocks;

  /// Tasks (or the rest of them) that didn't fit today.
  final List<OverflowItem> overflow;
}

/// Builds today's timeline. See the comment at the top of this file.
///
/// - [tasks]: open tasks only.
/// - [commitments]: busy blocks; only those overlapping today are used.
/// - [appliedVelocity]: from velocity.dart (1.0 until there are 3 logs).
/// - [now]: the current time; planning starts no earlier than this.
/// - [keepBlocks]: on re-plan, blocks that are done or already over. They
///   stay exactly as they were and count as busy time.
PlanResult plan({
  required List<Task> tasks,
  required List<Commitment> commitments,
  required Settings settings,
  required double appliedVelocity,
  required DateTime now,
  List<PlannedBlock> keepBlocks = const [],
}) {
  final planner = _DayPlanner(settings: settings, now: now);
  planner.addCommitmentsAndKeptBlocks(commitments, keepBlocks);

  final overflow = <OverflowItem>[];
  for (final task in sortByPriority(tasks, planner.day)) {
    final minutes = _minutesToSchedule(task, appliedVelocity);
    final remaining = planner.placeTask(task, minutes);
    if (remaining > 0) {
      overflow.add(
        OverflowItem(
          taskId: task.id,
          remainingMinutes: remaining,
          isUrgent: daysUntilDue(task.dueDate, planner.day) <= urgentWithinDays,
        ),
      );
    }
  }

  return PlanResult(
    blocks: List.unmodifiable(planner.sortedBlocks()),
    overflow: List.unmodifiable(overflow),
  );
}

/// Velocity-adjusted estimate minus what's already logged, at least
/// [minTaskMinutes], rounded up to the 5-minute grid.
int _minutesToSchedule(Task task, double appliedVelocity) {
  final left =
      adjustedMinutes(task.estimateMin, appliedVelocity) - task.loggedMin;
  return _roundUpToSlot(left > minTaskMinutes ? left : minTaskMinutes);
}

int _roundUpToSlot(int minutes) =>
    ((minutes + slotMinutes - 1) ~/ slotMinutes) * slotMinutes;

int _roundDownToSlot(int minutes) => (minutes ~/ slotMinutes) * slotMinutes;

/// A stretch of free time between busy periods.
class _Gap {
  _Gap(this.cursor, this.end);

  /// Where the next block would start. Moves forward as blocks are placed.
  int cursor;
  final int end;

  /// Minutes of work placed since the gap started or since the last break.
  int workSinceBreak = 0;

  int get free => end - cursor;
}

/// One piece of a layout: work or a break, in minutes after midnight.
class _Piece {
  const _Piece(this.start, this.length, {required this.isBreak});

  final int start;
  final int length;
  final bool isBreak;
}

/// The result of laying out some work at a gap's cursor.
class _Layout {
  const _Layout(this.pieces, this.end, this.workSinceBreak);

  final List<_Piece> pieces;
  final int end;
  final int workSinceBreak;
}

/// Holds one day's planning state: the free gaps and the blocks placed so
/// far. [plan] creates one, feeds it tasks in priority order, then reads the
/// finished timeline.
class _DayPlanner {
  _DayPlanner({required this.settings, required DateTime now})
    : day = DateTime(now.year, now.month, now.day),
      _windowStart = _windowStartFor(now, settings),
      _windowEnd = _roundDownToSlot(settings.workEndMinutes),
      _workLimit = _roundDownToSlot(settings.breakEveryMin),
      _breakLength = _roundUpToSlot(settings.breakLengthMin);

  final Settings settings;

  /// Midnight of the day being planned.
  final DateTime day;

  final int _windowStart;
  final int _windowEnd;

  /// Pomodoro rules from settings, kept on the 5-minute grid.
  final int _workLimit;
  final int _breakLength;
  bool get _usePomodoros => _workLimit > 0 && _breakLength > 0;

  final List<PlannedBlock> _blocks = [];
  List<_Gap> _gaps = [];

  /// The later of workStart and `now` (rounded up to 5 minutes, so
  /// 3:02 PM becomes 3:05 PM).
  static int _windowStartFor(DateTime now, Settings settings) {
    final hasSeconds =
        now.second > 0 || now.millisecond > 0 || now.microsecond > 0;
    final nowMinute = now.hour * 60 + now.minute + (hasSeconds ? 1 : 0);
    return _roundUpToSlot(
      nowMinute > settings.workStartMinutes
          ? nowMinute
          : settings.workStartMinutes,
    );
  }

  /// Wall-clock minutes after midnight of [day] (can be < 0 or > 1440 for
  /// times on other days).
  int _toMinute(DateTime time) {
    final dayOffset = DateTime.utc(
      time.year,
      time.month,
      time.day,
    ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
    return dayOffset * _minutesPerDay + time.hour * 60 + time.minute;
  }

  DateTime _toTime(int minute) =>
      DateTime(day.year, day.month, day.day, 0, minute);

  /// Puts today's commitments and kept blocks on the timeline and
  /// works out the free gaps around them.
  void addCommitmentsAndKeptBlocks(
    List<Commitment> commitments,
    List<PlannedBlock> keepBlocks,
  ) {
    final nextDay = DateTime(day.year, day.month, day.day + 1);
    final todaysCommitments = commitments
        .where((c) => c.end.isAfter(day) && c.start.isBefore(nextDay))
        .toList();
    for (final c in todaysCommitments) {
      _blocks.add(
        PlannedBlock(
          title: c.title,
          start: c.start,
          end: c.end,
          type: BlockType.commitment,
        ),
      );
    }
    // Kept blocks stay exactly as they were. Commitment blocks are skipped
    // here because commitments were just re-added from the list above.
    final kept = keepBlocks.where((b) => b.type != BlockType.commitment);
    _blocks.addAll(kept);

    final busy = <(int, int)>[
      for (final c in todaysCommitments)
        (_toMinute(c.start), _toMinute(c.end) + settings.bufferMin),
      for (final b in kept) (_toMinute(b.start), _toMinute(b.end)),
    ];
    _gaps = _windowStart < _windowEnd
        ? _freeGaps(_windowStart, _windowEnd, busy)
        : [];
  }

  /// places [minutes] of [task] on the timeline. Returns the
  /// minutes that didn't fit (0 if all of it fit).
  int placeTask(Task task, int minutes) {
    final whole = _placeInOneGap(minutes);
    if (whole != null) {
      _addTaskBlocks(task, whole, isSplit: whole.length > 1);
      return 0;
    }
    final (pieces, remaining) = _splitAcrossGaps(minutes);
    _addTaskBlocks(task, pieces, isSplit: pieces.length > 1 || remaining > 0);
    return remaining;
  }

  /// The earliest gap where all [minutes] (with breaks) fit. Returns the
  /// work pieces placed, or null if no gap is big enough.
  List<_Piece>? _placeInOneGap(int minutes) {
    for (final gap in _gaps) {
      final layout = _layout(gap, minutes);
      if (layout != null) return _commit(gap, layout);
    }
    return null;
  }

  /// Splits [minutes] across gaps in time order. Each gap takes the biggest
  /// amount (at least minChunkMin, on the 5-minute grid) that fits in it.
  /// Returns the work pieces placed and the minutes left over.
  (List<_Piece>, int) _splitAcrossGaps(int minutes) {
    final pieces = <_Piece>[];
    var remaining = minutes;
    for (final gap in _gaps) {
      final most = remaining < gap.free ? remaining : gap.free;
      for (
        var amount = _roundDownToSlot(most);
        amount >= settings.minChunkMin && amount > 0;
        amount -= slotMinutes
      ) {
        final layout = _layout(gap, amount);
        if (layout != null) {
          pieces.addAll(_commit(gap, layout));
          remaining -= amount;
          break;
        }
      }
      if (remaining == 0) break;
    }
    return (pieces, remaining);
  }

  /// Lays out [minutes] of work at the gap's cursor in pomodoros,
  /// without changing the gap. Returns null if it doesn't fit before the
  /// gap ends.
  _Layout? _layout(_Gap gap, int minutes) {
    final pieces = <_Piece>[];
    var cursor = gap.cursor;
    var work = gap.workSinceBreak;
    var remaining = minutes;

    while (remaining > 0) {
      var piece = remaining;
      if (_usePomodoros) {
        final room = _workLimit - work;
        // Break first if only a sliver of the session is left. There's
        // always more work after this break, so it's never a trailing one.
        if (work > 0 && room < minSegmentMin && room < remaining) {
          pieces.add(_Piece(cursor, _breakLength, isBreak: true));
          cursor += _breakLength;
          work = 0;
          continue;
        }
        piece = remaining < room ? remaining : room;
        // A leftover under 10 minutes joins this piece (up to 59 min).
        if (remaining - piece < minSegmentMin) piece = remaining;
      }
      pieces.add(_Piece(cursor, piece, isBreak: false));
      cursor += piece;
      work += piece;
      remaining -= piece;
    }

    return cursor <= gap.end ? _Layout(pieces, cursor, work) : null;
  }

  /// Adds the layout's breaks to the timeline, moves the gap's cursor, and
  /// returns just the work pieces.
  List<_Piece> _commit(_Gap gap, _Layout layout) {
    for (final p in layout.pieces.where((p) => p.isBreak)) {
      _blocks.add(
        PlannedBlock(
          title: 'Break',
          start: _toTime(p.start),
          end: _toTime(p.start + p.length),
          type: BlockType.breakTime,
        ),
      );
    }
    gap.cursor = layout.end;
    gap.workSinceBreak = layout.workSinceBreak;
    return layout.pieces.where((p) => !p.isBreak).toList();
  }

  /// One block per work piece, labelled "Title (1/3)" etc. when the
  /// task is in parts.
  void _addTaskBlocks(Task task, List<_Piece> pieces, {required bool isSplit}) {
    for (var i = 0; i < pieces.length; i++) {
      final piece = pieces[i];
      final title = !isSplit
          ? task.title
          : pieces.length == 1
          ? '${task.title} (part 1)'
          : '${task.title} (${i + 1}/${pieces.length})';
      _blocks.add(
        PlannedBlock(
          taskId: task.id,
          title: title,
          start: _toTime(piece.start),
          end: _toTime(piece.start + piece.length),
          type: BlockType.task,
          isChunk: isSplit,
        ),
      );
    }
  }

  /// Every block placed so far, by start time (then end time).
  List<PlannedBlock> sortedBlocks() {
    return _blocks..sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.end.compareTo(b.end);
    });
  }
}

/// The window minus the busy periods. Busy periods are clipped to the
/// window, widened to 5-minute boundaries, and merged where they overlap.
List<_Gap> _freeGaps(int windowStart, int windowEnd, List<(int, int)> busy) {
  final clipped = <(int, int)>[];
  for (final (start, end) in busy) {
    final s = start < windowStart ? windowStart : start;
    final e = end > windowEnd ? windowEnd : end;
    if (s < e) clipped.add((_roundDownToSlot(s), _roundUpToSlot(e)));
  }
  clipped.sort((a, b) => a.$1.compareTo(b.$1));

  final gaps = <_Gap>[];
  var cursor = windowStart;
  for (final (start, end) in clipped) {
    if (start > cursor) gaps.add(_Gap(cursor, start));
    if (end > cursor) cursor = end;
  }
  if (cursor < windowEnd) gaps.add(_Gap(cursor, windowEnd));
  return gaps;
}
