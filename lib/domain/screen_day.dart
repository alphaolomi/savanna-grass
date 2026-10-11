/// One local day of screen time, as SavannaTime's `/stats/summary` reports it.
///
/// Only aggregates cross into this app: totals, the productivity mix, and the
/// top app and category names. Window titles never leave the SavannaTime
/// server, and none of this ever leaves the phone for the AI — Gemma runs
/// on-device.
class ScreenDay {
  const ScreenDay({
    required this.totalSeconds,
    required this.secondsByLevel,
    required int? pulse,
    required this.topApps,
    int? scoredSeconds,
    int? uncategorizedSeconds,
    this.topCategories = const [],
    this.mostProductiveHour,
  })  : _pulse = pulse,
        _scored = scoredSeconds,
        _uncategorized = uncategorizedSeconds;

  final int totalSeconds;

  /// Seconds per productivity level, -2 (very distracting) .. +2.
  final Map<int, int> secondsByLevel;

  final int? _pulse;
  final int? _scored;
  final int? _uncategorized;

  final List<AppTime> topApps;
  final List<CategoryTime> topCategories;

  /// Local hour (0-23) with the best Pulse, when anything was scored.
  final int? mostProductiveHour;

  static const empty = ScreenDay(
    totalSeconds: 0,
    secondsByLevel: {},
    pulse: null,
    topApps: [],
  );

  /// Seconds that carry a productivity level — the Pulse denominator. Older
  /// cached days lack the field; the level buckets add up to the same thing.
  int get scoredSeconds => _scored ?? secondsByLevel.values.fold(0, (a, b) => a + b);

  int get uncategorizedSeconds =>
      _uncategorized ?? (totalSeconds - scoredSeconds).clamp(0, totalSeconds);

  /// Productivity Pulse 0-100, or null when nothing was scored. The summary
  /// endpoint reports 0 for an unscored day, but 0 means "as distracting as
  /// possible", so it is only believed when some time was actually scored.
  int? get pulse => scoredSeconds > 0 ? _pulse : null;

  int get distractingSeconds => (secondsByLevel[-2] ?? 0) + (secondsByLevel[-1] ?? 0);

  int get productiveSeconds => (secondsByLevel[1] ?? 0) + (secondsByLevel[2] ?? 0);

  /// The same shape [ScreenDay.fromSummaryJson] reads, so the last good day
  /// can be kept on the phone and shown on an offline cold start.
  Map<String, dynamic> toSummaryJson() => {
        'totalSeconds': totalSeconds,
        'scoredSeconds': scoredSeconds,
        'uncategorizedSeconds': uncategorizedSeconds,
        'secondsByLevel': {for (final e in secondsByLevel.entries) '${e.key}': e.value},
        'pulse': _pulse,
        'mostProductiveHour': mostProductiveHour,
        'topApps': [for (final a in topApps) a.toJson()],
        'topCategories': [for (final c in topCategories) c.toJson()],
      };

  factory ScreenDay.fromSummaryJson(Map<String, dynamic> json) {
    final apps = (json['topApps'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .where((a) => a['appName'] != null)
        .map(AppTime.fromJson)
        .toList();
    final categories = (json['topCategories'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(CategoryTime.fromJson)
        .toList();
    return ScreenDay(
      totalSeconds: _int(json['totalSeconds']) ?? 0,
      secondsByLevel: parseLevels(json['secondsByLevel']),
      pulse: _int(json['pulse']),
      scoredSeconds: _int(json['scoredSeconds']),
      uncategorizedSeconds: _int(json['uncategorizedSeconds']),
      mostProductiveHour: _int(json['mostProductiveHour']),
      topApps: apps,
      topCategories: categories,
    );
  }
}

class AppTime {
  const AppTime({
    required this.name,
    required this.seconds,
    this.productivity,
    this.category,
    this.sessions = 0,
  });

  final String name;
  final int seconds;

  /// Stored level -2..+2, or null when the app is uncategorized.
  final int? productivity;

  /// The category SavannaTime stored for the app, if any.
  final String? category;

  /// Tracked blocks behind [seconds] — how often it came back, not how long.
  final int sessions;

  Map<String, dynamic> toJson() => {
        'appName': name,
        'totalSeconds': seconds,
        'productivity': productivity,
        'category': category,
        'sessions': sessions,
      };

  factory AppTime.fromJson(Map<String, dynamic> a) => AppTime(
        name: a['appName'] as String,
        seconds: _int(a['totalSeconds']) ?? 0,
        productivity: _int(a['productivity']),
        category: a['category'] as String?,
        sessions: _int(a['sessions']) ?? 0,
      );
}

class CategoryTime {
  const CategoryTime({required this.name, required this.seconds, required this.secondsByLevel});

  final String name;
  final int seconds;
  final Map<int, int> secondsByLevel;

  Map<String, dynamic> toJson() => {
        'category': name,
        'totalSeconds': seconds,
        'secondsByLevel': {for (final e in secondsByLevel.entries) '${e.key}': e.value},
      };

  factory CategoryTime.fromJson(Map<String, dynamic> c) => CategoryTime(
        name: c['category'] as String? ?? 'uncategorized',
        seconds: _int(c['totalSeconds']) ?? 0,
        secondsByLevel: parseLevels(c['secondsByLevel']),
      );
}

/// One local day's totals, as `/stats/daily` reports them — enough to work out
/// that day's grass debt without fetching its whole summary.
class DayTotals {
  const DayTotals({required this.date, required this.totalSeconds, required this.secondsByLevel});

  /// `yyyy-mm-dd`, local to the account's zone.
  final String date;
  final int totalSeconds;
  final Map<int, int> secondsByLevel;

  int get distractingSeconds => (secondsByLevel[-2] ?? 0) + (secondsByLevel[-1] ?? 0);

  Map<String, dynamic> toJson() => {
        'date': date,
        'total': totalSeconds,
        'secondsByLevel': {for (final e in secondsByLevel.entries) '${e.key}': e.value},
      };

  factory DayTotals.fromJson(Map<String, dynamic> j) => DayTotals(
        date: j['date'] as String,
        totalSeconds: _int(j['total']) ?? 0,
        secondsByLevel: parseLevels(j['secondsByLevel']),
      );
}

/// One hour of a local day, as `/stats/timeline` reports it.
class HourSlice {
  const HourSlice({required this.hour, required this.totalSeconds, required this.secondsByLevel});

  final int hour;
  final int totalSeconds;
  final Map<int, int> secondsByLevel;

  int get distractingSeconds => (secondsByLevel[-2] ?? 0) + (secondsByLevel[-1] ?? 0);
  int get productiveSeconds => (secondsByLevel[1] ?? 0) + (secondsByLevel[2] ?? 0);

  /// Neutral and uncategorized time: on a screen, but neither way.
  int get otherSeconds => (totalSeconds - distractingSeconds - productiveSeconds).clamp(0, totalSeconds);

  factory HourSlice.fromJson(Map<String, dynamic> j) => HourSlice(
        hour: _int(j['hour']) ?? 0,
        totalSeconds: _int(j['totalSeconds']) ?? 0,
        secondsByLevel: parseLevels(j['secondsByLevel']),
      );

  /// All 24 hours, filling any the server left out, so the axis is complete.
  static List<HourSlice> fullDay(Iterable<HourSlice> hours) {
    final byHour = {for (final h in hours) h.hour: h};
    return [
      for (var h = 0; h < 24; h++) byHour[h] ?? HourSlice(hour: h, totalSeconds: 0, secondsByLevel: const {}),
    ];
  }
}

/// `{"-2": 60, "1": 300}` → `{-2: 60, 1: 300}`, skipping anything malformed.
Map<int, int> parseLevels(Object? raw) {
  if (raw is! Map) return const {};
  final out = <int, int>{};
  for (final e in raw.entries) {
    final k = int.tryParse('${e.key}');
    final v = e.value;
    if (k != null && v is num) out[k] = v.toInt();
  }
  return out;
}

int? _int(Object? v) => v is num ? v.toInt() : null;
