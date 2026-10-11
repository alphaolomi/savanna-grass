import '../domain/local_day.dart';

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Today", "Yesterday", or the weekday — how a person names a recent day.
String dayTitle(DateTime day, DateTime today) {
  final d = localDay(day);
  final t = localDay(today);
  if (d == t) return 'Today';
  if (d == addDays(t, -1)) return 'Yesterday';
  return _weekdays[d.weekday - 1];
}

/// "Thu 9 Oct".
String shortDate(DateTime day) {
  final d = day.toLocal();
  return '${_weekdays[d.weekday - 1].substring(0, 3)} ${d.day} ${_months[d.month - 1]}';
}

/// "18:05–18:27".
String timeRange(DateTime start, DateTime end) => '${clockTime(start)}–${clockTime(end)}';
