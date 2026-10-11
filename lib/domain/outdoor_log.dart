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
    final today = DateTime(now.year, now.month, now.day);
    final days = [for (var i = 6; i >= 0; i--) DateTime(today.year, today.month, today.day - i)];
    final seconds = List<int>.filled(7, 0);
    for (final b in breaks) {
      final l = b.start.toLocal();
      final idx = days.indexOf(DateTime(l.year, l.month, l.day));
      if (idx >= 0) seconds[idx] += b.seconds;
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
