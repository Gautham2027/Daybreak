import 'package:daybreak/models/commitment.dart';
import 'package:daybreak/services/calendar.dart';
import 'package:daybreak/services/calendar_convert.dart';

/// A CalendarService with made-up calendars and events, so the import flow
/// can be tested without the device_calendar_plus plugin.
class FakeCalendarService extends CalendarService {
  FakeCalendarService({
    this.supported = true,
    this.permission = CalendarPermission.granted,
    this.calendars = const [],
    this.events = const [],
    this.failReads = false,
  });

  final bool supported;
  CalendarPermission permission;
  List<DeviceCalendarInfo> calendars;
  List<CalendarEventData> events;
  bool failReads;
  int permissionRequests = 0;
  List<String> lastCalendarIds = const [];

  @override
  bool get isSupported => supported;

  @override
  Future<CalendarPermission> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> openSettings() async {}

  @override
  Future<List<DeviceCalendarInfo>> listCalendars() async => calendars;

  @override
  Future<List<Commitment>> eventsForDay(
    DateTime day,
    List<String> calendarIds, {
    bool includeAllDay = false,
  }) async {
    if (failReads) throw Exception('calendar unavailable');
    lastCalendarIds = calendarIds;
    return eventsToCommitments(events, day, includeAllDay: includeAllDay);
  }
}
