import 'local_day.dart';

/// A break spent outside, as logged to SavannaTime (or still queued locally).
class LoggedBreak {
  const LoggedBreak({
    required this.start,
    required this.end,
    required this.title,
    this.note,
    this.pending = false,
  });

  final DateTime start;
  final DateTime end;
  final String title;
  final String? note;

  /// True while it is queued on the phone and not yet on the server.
  final bool pending;

  int get seconds => end.difference(start).inSeconds;

  /// The part of this break that falls on the local [day]. A break across
  /// midnight is split between the two days rather than credited to the one
  /// it started on.
  int secondsOn(DateTime day) => overlapSeconds(start, end, day);

  Map<String, dynamic> toJson() => {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'title': title,
        if (note != null) 'note': note,
      };

  factory LoggedBreak.fromJson(Map<String, dynamic> j) => LoggedBreak(
        start: DateTime.parse(j['start'] as String).toLocal(),
        end: DateTime.parse(j['end'] as String).toLocal(),
        title: j['title'] as String,
        note: j['note'] as String?,
      );
}

/// The last seven local days of time outside, oldest first, plus the streak.
class OutdoorWeek {
  const OutdoorWeek({required this.days, required this.minutes, required this.streak});

  /// Local midnight of each of the seven days; the last one is today.
  final List<DateTime> days;
  final List<int> minutes;

  /// Consecutive days, ending today (or yesterday, if today has nothing yet),
  /// with at least [streakMinutes] outside.
  final int streak;

  static const streakMinutes = 5;

  int get totalMinutes => minutes.fold(0, (a, b) => a + b);

  factory OutdoorWeek.from(Iterable<LoggedBreak> breaks, DateTime now) {
    final today = localDay(now);
    final days = [for (var i = 6; i >= 0; i--) addDays(today, -i)];
    final seconds = List<int>.filled(7, 0);
    for (final b in breaks) {
      for (var i = 0; i < 7; i++) {
        seconds[i] += b.secondsOn(days[i]);
      }
    }
    final minutes = [for (final s in seconds) s ~/ 60];

    var i = 6;
    if (minutes[i] < streakMinutes) i--; // today is still young
    var streak = 0;
    while (i >= 0 && minutes[i] >= streakMinutes) {
      streak++;
      i--;
    }
    return OutdoorWeek(days: days, minutes: minutes, streak: streak);
  }
}
