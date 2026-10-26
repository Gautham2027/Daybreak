import '../models/task.dart';

// Priority score: decides which tasks get scheduled first.
//
//   score = 10 * importance + 40 / (daysUntilDue + 1) + 50 if overdue
//
// Importance is 1-3, so that part is worth 10-30 points. The deadline part
// is 40 if it's due today, 20 if it's due tomorrow, and keeps shrinking
// after that. Overdue tasks get +50, which puts them at the top.
//
// Examples: High task due tomorrow = 30 + 20 = 50.
//           Low task that's overdue = 10 + 40 + 50 = 100.
//
// `today` is passed in instead of using DateTime.now() so the tests can pick
// the day.

/// Points per importance level (Low = 1, Medium = 2, High = 3).
const int importanceWeight = 10;

/// Urgency points for a task due today; halves for tomorrow, and so on.
const double urgencyWeight = 40;

/// Extra points for a task whose due date has passed.
const double overdueBonus = 50;

/// Calendar days from [today] to [dueDate], ignoring time of day.
/// Negative when the task is overdue.
int _calendarDaysBetween(DateTime today, DateTime dueDate) {
  // Using UTC dates avoids daylight saving days being 23 or 25 hours long.
  final from = DateTime.utc(today.year, today.month, today.day);
  final to = DateTime.utc(dueDate.year, dueDate.month, dueDate.day);
  return to.difference(from).inDays;
}

/// Whole calendar days until the task is due, never less than 0 (an overdue
/// task counts as due today, plus the overdue bonus). Time of day is ignored,
/// so 11:59 PM and 12:01 AM on the same date give the same answer.
int daysUntilDue(DateTime dueDate, DateTime today) {
  final days = _calendarDaysBetween(today, dueDate);
  return days < 0 ? 0 : days;
}

/// True if the due date is before [today].
bool isOverdue(DateTime dueDate, DateTime today) =>
    _calendarDaysBetween(today, dueDate) < 0;

/// The task's priority score (see the formula at the top of this file).
/// Higher means it should be done sooner.
double priorityScore(Task task, DateTime today) {
  final days = daysUntilDue(task.dueDate, today);
  final bonus = isOverdue(task.dueDate, today) ? overdueBonus : 0;
  return importanceWeight * task.importance +
      urgencyWeight / (days + 1) +
      bonus;
}

/// A copy of [tasks], highest priority score first. Ties go to the earlier
/// due date, then the shorter task (quick wins first), then the title, so
/// the order is always the same for the same tasks.
List<Task> sortByPriority(List<Task> tasks, DateTime today) {
  final sorted = List<Task>.of(tasks);
  sorted.sort((a, b) {
    final byScore = priorityScore(b, today).compareTo(priorityScore(a, today));
    if (byScore != 0) return byScore;
    final byDue = a.dueDate.compareTo(b.dueDate);
    if (byDue != 0) return byDue;
    final byLength = a.estimateMin.compareTo(b.estimateMin);
    if (byLength != 0) return byLength;
    return a.title.compareTo(b.title);
  });
  return sorted;
}
