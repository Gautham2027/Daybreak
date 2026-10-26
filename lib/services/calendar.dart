import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/commitment.dart';
import 'calendar_convert.dart';

// Reads the phone's calendar using the device_calendar_plus package. This is
// the only file that touches the plugin. Every call is wrapped so the app
// still works if calendar access is denied or broken, and on the web it
// never calls the plugin at all.

/// The outcome of asking for calendar access.
enum CalendarPermission {
  /// The user allowed full access.
  granted,

  /// The user said no (or only allowed adding events).
  denied,

  /// No phone calendar here: running on the web, or the plugin failed.
  unavailable,
}

/// A phone calendar the user can choose to import from.
class DeviceCalendarInfo {
  const DeviceCalendarInfo({
    required this.id,
    required this.name,
    this.colorHex,
    this.accountName,
  });

  final String id;
  final String name;

  /// Like "#FF5722" or "#FFFF5722", straight from the phone.
  final String? colorHex;
  final String? accountName;
}

/// Reads the phone's calendars and today's events. Screens and providers
/// get it through Provider, so tests can swap in a fake.
class CalendarService {
  /// False on web: there's no phone calendar to read.
  bool get isSupported => !kIsWeb;

  /// Asks for full calendar access (iOS shows its permission prompt the
  /// first time). Never throws: any plugin error counts as unavailable.
  Future<CalendarPermission> requestPermission() async {
    if (!isSupported) return CalendarPermission.unavailable;
    try {
      final status = await DeviceCalendar.instance.requestPermissions();
      return status == CalendarPermissionStatus.granted
          ? CalendarPermission.granted
          : CalendarPermission.denied;
    } catch (_) {
      return CalendarPermission.unavailable;
    }
  }

  /// Opens this app's page in the phone's Settings (to turn access on).
  Future<void> openSettings() async {
    if (!isSupported) return;
    try {
      await DeviceCalendar.instance.openAppSettings();
    } catch (_) {
      // Nothing more to do: the dialog already told the user where to go.
    }
  }

  /// Calendars on the phone, or an empty list if they can't be read.
  Future<List<DeviceCalendarInfo>> listCalendars() async {
    if (!isSupported) return const [];
    try {
      final calendars = await DeviceCalendar.instance.listCalendars();
      return [
        for (final c in calendars)
          if (!c.hidden)
            DeviceCalendarInfo(
              id: c.id,
              name: c.name,
              colorHex: c.colorHex,
              accountName: c.accountName,
            ),
      ];
    } catch (_) {
      // The picker shows "No calendars found", and manual entry still works.
      return const [];
    }
  }

  /// Today's events from [calendarIds] as calendar Commitments.
  /// Throws if the calendar can't be read, so callers decide how loud to be.
  Future<List<Commitment>> eventsForDay(
    DateTime day,
    List<String> calendarIds, {
    bool includeAllDay = false,
  }) async {
    if (!isSupported || calendarIds.isEmpty) return const [];
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day + 1);
    final events = await DeviceCalendar.instance.listEvents(
      dayStart,
      dayEnd,
      calendarIds: calendarIds,
    );
    return eventsToCommitments(
      [
        for (final e in events)
          CalendarEventData(
            id: e.instanceId,
            title: e.title,
            start: e.startDate,
            end: e.endDate,
            isAllDay: e.isAllDay,
          ),
      ],
      day,
      includeAllDay: includeAllDay,
    );
  }
}
