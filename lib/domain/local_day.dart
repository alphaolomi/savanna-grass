/// Local calendar days.
///
/// A "day" in this app is always the phone's local midnight-to-midnight, the
/// same boundary SavannaTime uses when it buckets screen time in the user's
/// zone. Days are built with the [DateTime] constructor rather than by adding
/// 24 hours, so a DST day comes out 23 or 25 hours long instead of drifting
/// an hour into its neighbour.
library;

/// Local midnight at the start of the day [t] falls on.
DateTime localDay(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Local midnight [days] days after (or before, if negative) [day].
DateTime addDays(DateTime day, int days) => DateTime(day.year, day.month, day.day + days);

/// Seconds of the span [start]..[end] that fall inside the local [day].
///
/// A break from 23:50 to 00:10 is ten minutes on each side of midnight, and
/// pays ten minutes of each day's debt.
int overlapSeconds(DateTime start, DateTime end, DateTime day) {
  final from = localDay(day);
  final to = addDays(from, 1);
  final s = start.isAfter(from) ? start : from;
  final e = end.isBefore(to) ? end : to;
  return e.isAfter(s) ? e.difference(s).inSeconds : 0;
}

/// `yyyy-mm-dd` for the local date of [d], as SavannaTime's `from`/`to` take it.
String dateKey(DateTime d) {
  final l = d.toLocal();
  return '${l.year.toString().padLeft(4, '0')}-'
      '${l.month.toString().padLeft(2, '0')}-'
      '${l.day.toString().padLeft(2, '0')}';
}

/// `HH:mm` in local time.
String clockTime(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}
