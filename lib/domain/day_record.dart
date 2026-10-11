import 'grass_debt.dart';
import 'local_day.dart';
import 'outdoor_log.dart';
import 'screen_day.dart';

/// Everything the app knows about one local day in one place: screen time,
/// time outside, the breaks, and the debt that falls out of them.
class DayRecord {
  const DayRecord({
    required this.day,
    required this.screenSeconds,
    required this.distractingSeconds,
    required this.breaks,
    required this.outdoorSeconds,
    required this.debt,
    required this.screenKnown,
  });

  /// Local midnight.
  final DateTime day;
  final int screenSeconds;
  final int distractingSeconds;

  /// Breaks with any time on [day], newest first.
  final List<LoggedBreak> breaks;

  /// Time outside credited to [day] — a break across midnight counts only
  /// its share.
  final int outdoorSeconds;
  final GrassDebt debt;

  /// False when the server has not reported this day's screen time (offline,
  /// or nothing synced yet). Its debt then reads as zero, and the UI should
  /// say "unknown" rather than "paid".
  final bool screenKnown;

  int get outdoorMinutes => outdoorSeconds ~/ 60;

  factory DayRecord.build({
    required DateTime day,
    required int? screenSeconds,
    required int distractingSeconds,
    required Iterable<LoggedBreak> allBreaks,
  }) {
    final d = localDay(day);
    final breaks = allBreaks.where((b) => b.secondsOn(d) > 0).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    final outdoor = breaks.fold(0, (s, b) => s + b.secondsOn(d));
    return DayRecord(
      day: d,
      screenSeconds: screenSeconds ?? 0,
      distractingSeconds: distractingSeconds,
      breaks: breaks,
      outdoorSeconds: outdoor,
      screenKnown: screenSeconds != null,
      debt: GrassDebt.fromSeconds(
        screenSeconds: screenSeconds ?? 0,
        distractingSeconds: distractingSeconds,
        outdoorSeconds: outdoor,
      ),
    );
  }
}

/// The record for one local [day], from the best numbers available:
///
/// 1. its loaded [detail] (a fresh `/stats/summary` for that day);
/// 2. for today, [todayScreen] — the live summary the hero shows;
/// 3. its row in [weekTotals] (`/stats/daily`).
///
/// [weekTotals] is null when the week has not been read; a day it does not
/// list then is unknown. A day missing from a week that *was* read, inside
/// that week, had no screen time.
DayRecord recordForDay({
  required DateTime day,
  required DateTime today,
  required Iterable<LoggedBreak> breaks,
  ScreenDay? todayScreen,
  DayDetail? detail,
  Iterable<DayTotals>? weekTotals,
}) {
  final d = localDay(day);
  final t = localDay(today);
  final screen = detail?.screen ?? (d == t ? todayScreen : null);
  if (screen != null) {
    return DayRecord.build(
      day: d,
      screenSeconds: screen.totalSeconds,
      distractingSeconds: screen.distractingSeconds,
      allBreaks: breaks,
    );
  }
  final key = dateKey(d);
  DayTotals? row;
  for (final r in weekTotals ?? const <DayTotals>[]) {
    if (r.date == key) row = r;
  }
  final inWeek = !d.isAfter(t) && !d.isBefore(addDays(t, -6));
  return DayRecord.build(
    day: d,
    screenSeconds: row?.totalSeconds ?? (weekTotals != null && inWeek ? 0 : null),
    distractingSeconds: row?.distractingSeconds ?? 0,
    allBreaks: breaks,
  );
}

/// The last seven local days, oldest first, ending with [today].
List<DayRecord> buildWeek({
  required DateTime today,
  required Iterable<LoggedBreak> breaks,
  ScreenDay? todayScreen,
  Iterable<DayTotals>? weekTotals,
  DayDetail? Function(DateTime day)? detailFor,
}) {
  final t = localDay(today);
  return [
    for (var i = 6; i >= 0; i--)
      recordForDay(
        day: addDays(t, -i),
        today: t,
        breaks: breaks,
        todayScreen: todayScreen,
        detail: detailFor?.call(addDays(t, -i)),
        weekTotals: weekTotals,
      ),
  ];
}

/// Seconds outside in each of [day]'s 24 local hours, hour 0 first.
List<int> outdoorSecondsByHour(Iterable<LoggedBreak> breaks, DateTime day) {
  final d = localDay(day);
  final out = List<int>.filled(24, 0);
  for (var h = 0; h < 24; h++) {
    final from = DateTime(d.year, d.month, d.day, h);
    final to = DateTime(d.year, d.month, d.day, h + 1);
    for (final b in breaks) {
      final s = b.start.isAfter(from) ? b.start : from;
      final e = b.end.isBefore(to) ? b.end : to;
      if (e.isAfter(s)) out[h] += e.difference(s).inSeconds;
    }
  }
  return out;
}

/// A day's full picture for its detail page: the summary, its 24 hours, and
/// the record built from them.
class DayDetail {
  const DayDetail({required this.screen, required this.hours});

  final ScreenDay screen;

  /// Always 24 entries, hour 0 first.
  final List<HourSlice> hours;
}
