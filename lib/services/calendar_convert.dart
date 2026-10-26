import '../models/commitment.dart';

// The part of calendar import that doesn't need the plugin: turning calendar
// events into Commitments and merging a new import with what's already
// saved. Keeping it separate from calendar.dart means it can be unit tested.

/// The bits of a phone calendar event Daybreak needs.
class CalendarEventData {
  const CalendarEventData({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.isAllDay = false,
  });

  /// Unique per occurrence (recurring events get one id per day).
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool isAllDay;
}

/// Events that overlap [day], as calendar Commitments clipped to that day.
/// All-day events are skipped unless [includeAllDay] is true.
List<Commitment> eventsToCommitments(
  List<CalendarEventData> events,
  DateTime day, {
  bool includeAllDay = false,
}) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = DateTime(day.year, day.month, day.day + 1);

  final commitments = <Commitment>[];
  for (final event in events) {
    if (event.isAllDay && !includeAllDay) continue;
    // All-day events cover the whole day.
    final start = event.isAllDay ? dayStart : event.start;
    final end = event.isAllDay ? dayEnd : event.end;
    if (!end.isAfter(dayStart) || !start.isBefore(dayEnd)) continue;
    if (!end.isAfter(start)) continue;

    commitments.add(
      Commitment.create(
        title: event.title.trim().isEmpty ? 'Busy' : event.title.trim(),
        start: start.isBefore(dayStart) ? dayStart : start,
        end: end.isAfter(dayEnd) ? dayEnd : end,
        source: CommitmentSource.calendar,
        externalId: event.id,
      ),
    );
  }
  commitments.sort((a, b) => a.start.compareTo(b.start));
  return commitments;
}

/// What to change in storage after an import.
class CalendarMerge {
  const CalendarMerge({
    required this.toAdd,
    required this.toUpdate,
    required this.toRemove,
  });

  final List<Commitment> toAdd;
  final List<Commitment> toUpdate;
  final List<Commitment> toRemove;
}

/// Compares today's saved commitments with a fresh [imported] list, by
/// externalId:
/// - new events are added,
/// - events whose title or times changed are updated (keeping the saved id
///   and whether the user hid it),
/// - calendar commitments whose event is gone are removed.
/// Manual commitments are never touched.
CalendarMerge mergeCalendarCommitments({
  required List<Commitment> existing,
  required List<Commitment> imported,
}) {
  final saved = {
    for (final c in existing)
      if (c.isFromCalendar && c.externalId != null) c.externalId!: c,
  };
  final importedIds = imported.map((c) => c.externalId).toSet();

  final toAdd = <Commitment>[];
  final toUpdate = <Commitment>[];
  for (final fresh in imported) {
    final old = saved[fresh.externalId];
    if (old == null) {
      toAdd.add(fresh);
    } else if (old.title != fresh.title ||
        old.start != fresh.start ||
        old.end != fresh.end) {
      toUpdate.add(
        old.copyWith(title: fresh.title, start: fresh.start, end: fresh.end),
      );
    }
  }
  final toRemove = [
    for (final c in existing)
      if (c.isFromCalendar && !importedIds.contains(c.externalId)) c,
  ];
  return CalendarMerge(toAdd: toAdd, toUpdate: toUpdate, toRemove: toRemove);
}
