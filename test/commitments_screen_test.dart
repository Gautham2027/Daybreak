import 'package:daybreak/models/settings.dart';
import 'package:daybreak/screens/commitments_screen.dart';
import 'package:daybreak/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daybreak/models/commitment.dart';
import 'package:daybreak/services/calendar.dart';
import 'package:daybreak/services/calendar_convert.dart';

import 'fakes/fake_calendar.dart';
import 'fakes/in_memory_storage.dart';
import 'fakes/test_app.dart';

DateTime todayAt(int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

FakeCalendarService schoolCalendar() => FakeCalendarService(
  calendars: const [
    DeviceCalendarInfo(
      id: 'school',
      name: 'School',
      colorHex: '#FF3F51B5',
      accountName: 'student@school.edu',
    ),
  ],
  events: [
    CalendarEventData(
      id: 'ev-1',
      title: 'Chemistry lab',
      start: todayAt(16),
      end: todayAt(17),
    ),
    CalendarEventData(
      id: 'ev-2',
      title: 'Band practice',
      start: todayAt(18),
      end: todayAt(19, 30),
    ),
  ],
);

void main() {
  testWidgets('adding a commitment via the form shows it in the list', (
    tester,
  ) async {
    final providers = TestProviders();
    await tester.pumpWidget(
      providers.wrap(const MaterialApp(home: CommitmentsScreen())),
    );

    expect(find.text('No commitments today'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New commitment'), findsOneWidget);

    // Quick-pick chip fills in the title.
    await tester.tap(find.widgetWithText(ActionChip, 'Practice'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('New commitment'), findsNothing);
    expect(find.text('No commitments today'), findsNothing);
    expect(find.text('Practice'), findsOneWidget);
    expect(providers.commitments.commitments.single.title, 'Practice');
  });

  testWidgets('Save is disabled without a title', (tester) async {
    await tester.pumpWidget(
      TestProviders().wrap(const MaterialApp(home: CommitmentsScreen())),
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });

  group('calendar events', () {
    Future<TestProviders> pump(
      WidgetTester tester,
      FakeCalendarService calendar, {
      List<Commitment> commitments = const [],
      Widget home = const CommitmentsScreen(),
    }) async {
      final providers = TestProviders(
        InMemoryStorage(
          commitments: commitments,
          settings: const Settings(selectedCalendarIds: ['school']),
        ),
        calendar,
      );
      await tester.pumpWidget(providers.wrap(MaterialApp(home: home)));
      return providers;
    }

    /// Imports the fake calendar the same way Plan my day does.
    Future<void> importNow(WidgetTester tester, TestProviders p) async {
      await p.commitments.importFromCalendar(
        p.calendar,
        p.settings.settings,
        DateTime.now(),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('there is no import button on the Commitments screen', (
      tester,
    ) async {
      await pump(tester, schoolCalendar());
      expect(find.text('Import from calendar'), findsNothing);
      expect(find.text('No commitments today'), findsOneWidget);
    });

    testWidgets('imported events show with a calendar icon', (tester) async {
      final providers = await pump(tester, schoolCalendar());
      await importNow(tester, providers);

      expect(find.text('Chemistry lab'), findsOneWidget);
      expect(find.text('Band practice'), findsOneWidget);
      expect(find.textContaining('From calendar'), findsNWidgets(2));
      expect(find.byIcon(Icons.calendar_month), findsNWidgets(2));
    });

    testWidgets('re-import keeps manual commitments', (tester) async {
      final calendar = schoolCalendar();
      final providers = await pump(
        tester,
        calendar,
        commitments: [
          Commitment(
            id: 'dinner',
            title: 'Dinner',
            start: todayAt(19, 30),
            end: todayAt(20),
          ),
        ],
      );
      await importNow(tester, providers);
      expect(providers.commitments.commitments, hasLength(3));

      // One event is cancelled in the calendar, then it's imported again.
      calendar.events = calendar.events.take(1).toList();
      await importNow(tester, providers);
      expect(providers.commitments.commitments.map((c) => c.title), [
        'Chemistry lab',
        'Dinner',
      ]);
    });

    testWidgets('calendar events can be hidden but not edited', (tester) async {
      final providers = await pump(tester, schoolCalendar());
      await importNow(tester, providers);

      await tester.tap(find.text('Chemistry lab'));
      await tester.pumpAndSettle();
      expect(find.text('Edit commitment'), findsNothing);
      expect(find.textContaining('comes from your calendar'), findsOneWidget);
      // Wait for that SnackBar to go away.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Chemistry lab'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Hidden for today'), findsOneWidget);
      expect(find.text('Chemistry lab'), findsNothing);

      // Importing again doesn't bring it back.
      await importNow(tester, providers);
      expect(find.text('Chemistry lab'), findsNothing);
      expect(providers.commitments.commitments.single.title, 'Band practice');
    });

    testWidgets('Settings: choose calendars saves the choice', (tester) async {
      final providers = TestProviders(InMemoryStorage(), schoolCalendar());
      await tester.pumpWidget(
        providers.wrap(const MaterialApp(home: SettingsScreen())),
      );
      await tester.scrollUntilVisible(find.text('Choose calendars'), 300);
      await tester.tap(find.text('Choose calendars'));
      await tester.pumpAndSettle();
      expect(find.text('student@school.edu'), findsOneWidget);

      await tester.tap(find.text('School'));
      await tester.pump();
      await tester.tap(find.text('Use 1 calendar'));
      await tester.pumpAndSettle();
      expect(providers.settings.settings.selectedCalendarIds, ['school']);
    });

    testWidgets('Settings: denied permission explains how to fix it', (
      tester,
    ) async {
      final providers = TestProviders(
        InMemoryStorage(),
        FakeCalendarService(permission: CalendarPermission.denied),
      );
      await tester.pumpWidget(
        providers.wrap(const MaterialApp(home: SettingsScreen())),
      );
      await tester.scrollUntilVisible(find.text('Choose calendars'), 300);
      await tester.tap(find.text('Choose calendars'));
      await tester.pumpAndSettle();
      expect(find.text('Calendar access is off'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(providers.settings.settings.selectedCalendarIds, isEmpty);
    });
  });
}
