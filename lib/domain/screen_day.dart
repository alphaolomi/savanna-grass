/// One local day of screen time, as SavannaTime's `/stats/summary` reports it.
///
/// Only aggregates cross into this app: totals, the productivity mix and the
/// top app names. Window titles never leave the SavannaTime server, and none of
/// this ever leaves the phone for the AI — Gemma runs on-device.
class ScreenDay {
  const ScreenDay({
    required this.totalSeconds,
    required this.secondsByLevel,
    required this.pulse,
    required this.topApps,
  });

  final int totalSeconds;

  /// Seconds per productivity level, -2 (very distracting) .. +2.
  final Map<int, int> secondsByLevel;

  /// Productivity Pulse 0-100, or null when nothing was scored. Never treat
  /// null as 0: 0 means "as distracting as possible".
  final int? pulse;

  final List<AppTime> topApps;

  static const empty = ScreenDay(
    totalSeconds: 0,
    secondsByLevel: {},
    pulse: null,
    topApps: [],
  );

  int get distractingSeconds =>
      (secondsByLevel[-2] ?? 0) + (secondsByLevel[-1] ?? 0);

  factory ScreenDay.fromSummaryJson(Map<String, dynamic> json) {
    final levels = (json['secondsByLevel'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
    final apps = (json['topApps'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .where((a) => a['appName'] != null)
        .map(
          (a) => AppTime(
            name: a['appName'] as String,
            seconds: (a['totalSeconds'] as num).toInt(),
            productivity: (a['productivity'] as num?)?.toInt(),
          ),
        )
        .toList();
    return ScreenDay(
      totalSeconds: (json['totalSeconds'] as num? ?? 0).toInt(),
      secondsByLevel: levels,
      pulse: (json['pulse'] as num?)?.toInt(),
      topApps: apps,
    );
  }
}

class AppTime {
  const AppTime({required this.name, required this.seconds, this.productivity});

  final String name;
  final int seconds;

  /// Stored level -2..+2, or null when the app is uncategorized.
  final int? productivity;
}
