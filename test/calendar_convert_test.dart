import 'package:daybreak/models/commitment.dart';
import 'package:daybreak/services/calendar_convert.dart';
import 'package:flutter_test/flutter_test.dart';

final day = DateTime(2026, 10, 26);
DateTime t(int hour, [int minute = 0]) => DateTime(2026, 10, 26, hour, minute);

CalendarEventData event(
  String id,
  DateTime start,
  DateTime end, {
  String title = 'Event',
  bool allDay = false,
}) => CalendarEventData(
  id: id,
  title: title,
  start: start,
  end: end,
  isAllDay: allDay,
);

void main() {
  group('eventsToCommitments', () {
    test('timed event becomes a calendar Commitment', () {
      final result = eventsToCommitments([
        event('e1', t(16), t(17, 30), title: 'Soccer practice'),
      ], day);
      final c = result.single;
      expect(c.title, 'Soccer practice');
      expect(c.start, t(16));
      expect(c.end, t(17, 30));
      expect(c.source, CommitmentSource.calendar);
      expect(c.externalId, 'e1');
      expect(c.id, isNotEmpty);
      expect(c.hidden, isFalse);
    });

    test('all-day events are skipped unless included', () {
      final allDay = event('a', day, DateTime(2026, 10, 27), allDay: true);
      expect(eventsToCommitments([allDay], day), isEmpty);
      final included = eventsToCommitments(
        [allDay],
        day,
        includeAllDay: true,
      ).single;
      expect(included.start, day);
      expect(included.end, DateTime(2026, 10, 27));
    });

    test('events crossing midnight are clipped to the day', () {
      final result = eventsToCommitments([
        event('late', t(22), DateTime(2026, 10, 27, 1)),
        event('early', DateTime(2026, 10, 25, 23), t(1)),
      ], day);
      expect(result.map((c) => (c.externalId, c.start, c.end)), [
        ('early', day, t(1)),
        ('late', t(22), DateTime(2026, 10, 27)),
      ]);
    });

    test('events on other days and empty events are skipped', () {
      final result = eventsToCommitments([
        event(
          'tomorrow',
          DateTime(2026, 10, 27, 9),
          DateTime(2026, 10, 27, 10),
        ),
        event(
          'yesterday',
          DateTime(2026, 10, 25, 9),
          DateTime(2026, 10, 25, 10),
        ),
        event('zero', t(9), t(9)),
      ], day);
      expect(result, isEmpty);
    });

    test('untitled events are called Busy, results sorted by start', () {
      final result = eventsToCommitments([
        event('b', t(18), t(19), title: '  '),
        event('a', t(9), t(10), title: 'Class'),
      ], day);
      expect(result.map((c) => c.title), ['Class', 'Busy']);
    });
  });

  group('mergeCalendarCommitments', () {
    Commitment saved(
      String externalId,
      DateTime start,
      DateTime end, {
      String title = 'Event',
      bool hidden = false,
    }) => Commitment(
      id: 'saved-$externalId',
      title: title,
      start: start,
      end: end,
      source: CommitmentSource.calendar,
      externalId: externalId,
      hidden: hidden,
    );

    Commitment fresh(
      String externalId,
      DateTime start,
      DateTime end, {
      String title = 'Event',
    }) => Commitment(
      id: 'fresh-$externalId',
      title: title,
      start: start,
      end: end,
      source: CommitmentSource.calendar,
      externalId: externalId,
    );

    final manual = Commitment(
      id: 'manual',
      title: 'Dinner',
      start: t(18),
      end: t(19),
    );

    test('adds new, updates changed, removes gone; manual untouched', () {
      final merge = mergeCalendarCommitments(
        existing: [
          manual,
          saved('same', t(9), t(10)),
          saved('moved', t(11), t(12)),
          saved('gone', t(13), t(14)),
        ],
        imported: [
          fresh('same', t(9), t(10)),
          fresh('moved', t(11, 30), t(12, 30)),
          fresh('new', t(15), t(16)),
        ],
      );

      expect(merge.toAdd.map((c) => c.externalId), ['new']);
      expect(merge.toUpdate.single.id, 'saved-moved');
      expect(merge.toUpdate.single.start, t(11, 30));
      expect(merge.toRemove.map((c) => c.id), ['saved-gone']);
      final touched = [...merge.toAdd, ...merge.toUpdate, ...merge.toRemove];
      expect(touched.map((c) => c.id), isNot(contains('manual')));
    });

    test('a renamed event is updated', () {
      final merge = mergeCalendarCommitments(
        existing: [saved('e', t(9), t(10), title: 'Math')],
        imported: [fresh('e', t(9), t(10), title: 'Math test')],
      );
      expect(merge.toUpdate.single.title, 'Math test');
    });

    test('hidden events stay hidden when updated', () {
      final merge = mergeCalendarCommitments(
        existing: [saved('e', t(9), t(10), hidden: true)],
        imported: [fresh('e', t(9, 15), t(10))],
      );
      expect(merge.toUpdate.single.hidden, isTrue);
      expect(merge.toAdd, isEmpty);
    });

    test('nothing to do when everything matches', () {
      final merge = mergeCalendarCommitments(
        existing: [manual, saved('e', t(9), t(10))],
        imported: [fresh('e', t(9), t(10))],
      );
      expect(merge.toAdd, isEmpty);
      expect(merge.toUpdate, isEmpty);
      expect(merge.toRemove, isEmpty);
    });

    test('an empty import removes all calendar commitments only', () {
      final merge = mergeCalendarCommitments(
        existing: [manual, saved('e', t(9), t(10))],
        imported: const [],
      );
      expect(merge.toRemove.map((c) => c.id), ['saved-e']);
    });
  });
}
