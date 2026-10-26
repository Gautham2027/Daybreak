import 'package:intl/intl.dart';

import 'scoring.dart';

// Text formatting used by the screens (times, dates, durations).

/// "30 min", "1 hr", "1 hr 30 min".
String formatEstimate(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours hr' : '$hours hr $rest min';
}

/// "Wed, Oct 28", with the year added if it isn't this year.
String _shortDate(DateTime date, DateTime today) {
  final pattern = date.year == today.year ? 'EEE, MMM d' : 'EEE, MMM d, y';
  return DateFormat(pattern).format(date);
}

/// Due label for task lists: "Overdue by 2 days", "Due today",
/// "Due tomorrow", or "Due Wed, Oct 28".
String dueLabel(DateTime dueDate, DateTime today) {
  if (isOverdue(dueDate, today)) {
    final todayUtc = DateTime.utc(today.year, today.month, today.day);
    final dueUtc = DateTime.utc(dueDate.year, dueDate.month, dueDate.day);
    final late = todayUtc.difference(dueUtc).inDays;
    return late == 1 ? 'Overdue by 1 day' : 'Overdue by $late days';
  }
  final days = daysUntilDue(dueDate, today);
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  return 'Due ${_shortDate(dueDate, today)}';
}

/// Date label for the task form: "Today, Oct 26", "Tomorrow, Oct 27",
/// "Yesterday, Oct 25", or "Wed, Oct 28".
String formDateLabel(DateTime date, DateTime today) {
  final monthDay = DateFormat('MMM d').format(date);
  if (isOverdue(date, today)) {
    final yesterday = today.subtract(const Duration(days: 1));
    if (!isOverdue(date, yesterday)) return 'Yesterday, $monthDay';
    return _shortDate(date, today);
  }
  final days = daysUntilDue(date, today);
  if (days == 0) return 'Today, $monthDay';
  if (days == 1) return 'Tomorrow, $monthDay';
  return _shortDate(date, today);
}

/// "3:30 PM".
String formatTime(DateTime time) => DateFormat('h:mm a').format(time);

/// "4:00 – 5:30 PM", or "11:30 AM – 12:30 PM" when AM/PM differs.
String formatTimeRange(DateTime start, DateTime end) {
  final sameHalf = (start.hour < 12) == (end.hour < 12);
  final startText = sameHalf
      ? DateFormat('h:mm').format(start)
      : formatTime(start);
  return '$startText – ${formatTime(end)}';
}

/// Minutes after midnight (like Settings.workStartMinutes) as "3:00 PM".
String formatMinutesOfDay(int minutes) =>
    formatTime(DateTime(2000, 1, 1, 0, minutes));

/// "Good morning" before noon, "Good afternoon" until 5 PM, then evening.
String greetingFor(DateTime time) {
  if (time.hour < 12) return 'Good morning';
  if (time.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// "Monday, October 26".
String formatLongDate(DateTime date) => DateFormat('EEEE, MMMM d').format(date);

/// Timer display: "4:05" (m:ss) or "1:02:05" (h:mm:ss).
String formatTimer(Duration elapsed) {
  final hours = elapsed.inHours;
  final minutes = elapsed.inMinutes % 60;
  final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
  if (hours == 0) return '$minutes:$seconds';
  return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
}

/// Splits a planner block title like "Essay (1/2)" or "Essay (part 1)" into
/// the task name and its segment badge ("1/2", "part 1"), for display.
/// Titles without a segment suffix come back with a null badge.
({String title, String? badge}) splitSegmentTitle(String blockTitle) {
  final match = RegExp(r'^(.*) \((\d+/\d+|part \d+)\)$').firstMatch(blockTitle);
  if (match == null) return (title: blockTitle, badge: null);
  return (title: match.group(1)!, badge: match.group(2)!);
}

/// Groups on the Tasks screen, in display order.
enum DueGroup {
  overdue('Overdue'),
  today('Today'),
  tomorrow('Tomorrow'),
  thisWeek('This week'),
  later('Later');

  const DueGroup(this.label);

  final String label;
}

/// Which Tasks-screen group a task due on [dueDate] belongs in: overdue,
/// today, tomorrow, within the next 7 days ("This week"), or later.
DueGroup dueGroupFor(DateTime dueDate, DateTime today) {
  if (isOverdue(dueDate, today)) return DueGroup.overdue;
  final days = daysUntilDue(dueDate, today);
  if (days == 0) return DueGroup.today;
  if (days == 1) return DueGroup.tomorrow;
  if (days < 7) return DueGroup.thisWeek;
  return DueGroup.later;
}
