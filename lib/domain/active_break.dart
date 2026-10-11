/// A break in progress.
///
/// Saved to the phone the moment it starts. The person is told to put the
/// phone in a pocket, and Android reclaims backgrounded apps freely — this one
/// holds a ~550 MB model in memory — so a break that lived only in a widget
/// would often be gone by the time they came back inside.
class ActiveBreak {
  const ActiveBreak({
    required this.id,
    required this.title,
    required this.steps,
    required this.minutes,
    required this.start,
    this.note = '',
  });

  /// Becomes the SavannaTime time entry's id, so a break finished twice (a
  /// crash between queueing it and clearing it) is still logged once.
  final String id;
  final String title;
  final String steps;

  /// The quest's target length.
  final int minutes;
  final DateTime start;

  /// "What did you notice?", as typed so far.
  final String note;

  /// The most one break counts for. A break left running — the phone forgotten
  /// in a jacket overnight — must not log a night outside.
  static const maxLength = Duration(hours: 3);

  /// Shorter than this is a mis-tap, not time outside, and is not logged.
  static const minLength = Duration(minutes: 1);

  DateTime get targetAt => start.add(Duration(minutes: minutes));

  /// When the break counts as having ended if finished at [now]: never before
  /// it started (a clock set backwards), never past [maxLength].
  DateTime endAt(DateTime now) {
    if (now.isBefore(start)) return start;
    final cap = start.add(maxLength);
    return now.isAfter(cap) ? cap : now;
  }

  bool isTooShort(DateTime now) => endAt(now).difference(start) < minLength;

  ActiveBreak withNote(String note) => ActiveBreak(
        id: id,
        title: title,
        steps: steps,
        minutes: minutes,
        start: start,
        note: note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'steps': steps,
        'minutes': minutes,
        'start': start.toUtc().toIso8601String(),
        'note': note,
      };

  factory ActiveBreak.fromJson(Map<String, dynamic> j) => ActiveBreak(
        id: j['id'] as String,
        title: j['title'] as String,
        steps: j['steps'] as String? ?? '',
        minutes: (j['minutes'] as num).toInt(),
        start: DateTime.parse(j['start'] as String).toLocal(),
        note: j['note'] as String? ?? '',
      );
}
