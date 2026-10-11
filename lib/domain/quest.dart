import 'grass_debt.dart';
import 'screen_day.dart';

/// Where the person is right now — changes what a sensible quest looks like.
enum Setting {
  home('at home'),
  work('at work or on campus'),
  city('out in town');

  const Setting(this.phrase);
  final String phrase;
}

/// A short outdoor invitation.
class Quest {
  const Quest({
    required this.title,
    required this.minutes,
    required this.steps,
    required this.why,
    required this.source,
  });

  final String title;
  final int minutes;
  final String steps;
  final String why;

  /// Who wrote it: the on-device model, or the deterministic fallback.
  final QuestSource source;
}

enum QuestSource { gemma, template }

/// Everything the model is told. Built from aggregates only — no window
/// titles, no URLs — and it never leaves the phone.
class QuestContext {
  const QuestContext({
    required this.day,
    required this.debt,
    required this.now,
    required this.setting,
  });

  final ScreenDay day;
  final GrassDebt debt;
  final DateTime now;
  final Setting setting;

  /// Minutes the quest should take: today's remaining debt, kept inside a range
  /// a person will actually say yes to.
  int get targetMinutes => debt.remainingMinutes.clamp(5, 30);

  String get partOfDay {
    final h = now.hour;
    if (h < 5) return 'late night';
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    if (h < 21) return 'evening';
    return 'night';
  }

  bool get isDark => now.hour < 6 || now.hour >= 19;
}

String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];

/// The prompt for Gemma 3 1B. Small models follow a rigid line format far more
/// reliably than JSON, so the answer is four labelled lines.
String buildQuestPrompt(QuestContext c) {
  final apps = c.day.topApps
      .take(3)
      .map((a) => '${a.name} (${formatDuration(a.seconds)})')
      .join(', ');
  final safety = c.isDark
      ? 'It is dark outside, so keep it close, lit and safe — a balcony, doorstep, or well-lit street.'
      : 'It is daylight.';
  return '''
You are a warm, playful coach who gets people off their screens and outside.
Write ONE small outdoor quest for this person.

Facts about their day:
- Screen time today: ${formatDuration(c.day.totalSeconds)}
- Of that, distracting: ${formatDuration(c.day.distractingSeconds)}
- Most used apps: ${apps.isEmpty ? 'unknown' : apps}
- It is a ${_months[c.now.month - 1]} ${c.partOfDay}. They are ${c.setting.phrase}.
- $safety
- The quest must take about ${c.targetMinutes} minutes.

Rules: it must happen outdoors, need no equipment, no purchases and no phone use.
Make it specific and sensory (something to notice, find, or count).

Answer with exactly these four lines and nothing else:
TITLE: <a fun title, at most 6 words>
MINUTES: <a number>
STEPS: <one or two sentences saying exactly what to do>
WHY: <one short sentence linking it to their screen time today>''';
}

final _line = RegExp(r'^\s*\**\s*(TITLE|MINUTES|STEPS|WHY)\s*\**\s*:\s*(.+)$',
    caseSensitive: false, multiLine: true);

/// Parses the model's answer. Returns null when the output is not usable, so
/// the caller falls back to a template rather than showing half a quest.
Quest? parseQuest(String raw, {required int fallbackMinutes}) {
  final fields = <String, String>{};
  for (final m in _line.allMatches(raw)) {
    fields.putIfAbsent(
      m.group(1)!.toUpperCase(),
      () => m.group(2)!.replaceAll('**', '').trim(),
    );
  }
  final title = fields['TITLE'];
  final steps = fields['STEPS'];
  if (title == null || title.isEmpty || steps == null || steps.isEmpty) {
    return null;
  }
  final minutes = int.tryParse(
        RegExp(r'\d+').firstMatch(fields['MINUTES'] ?? '')?.group(0) ?? '',
      ) ??
      fallbackMinutes;
  return Quest(
    title: _trimQuotes(title),
    minutes: minutes.clamp(3, 60),
    steps: steps,
    why: fields['WHY'] ?? '',
    source: QuestSource.gemma,
  );
}

String _trimQuotes(String s) => s.replaceAll(RegExp(r'''^["'“]+|["'”]+$'''), '');

/// Deterministic quests for when the model is not downloaded yet, or its
/// answer does not parse. The app always has something to offer outside.
Quest templateQuest(QuestContext c, {int seed = 0}) {
  final pool = c.isDark ? _darkQuests : _dayQuests;
  final q = pool[(seed + c.now.day + c.now.hour) % pool.length];
  return Quest(
    title: q.$1,
    minutes: c.targetMinutes,
    steps: q.$2,
    why: c.day.totalSeconds == 0
        ? 'A head start before the screens win today.'
        : '${formatDuration(c.day.totalSeconds)} on screens today — your eyes have earned a horizon.',
    source: QuestSource.template,
  );
}

const _dayQuests = [
  ('Five Shades of Green', 'Walk outside and find five different shades of green. Touch the softest one.'),
  ('Sky Survey', 'Find somewhere you can see open sky. Count the birds you spot until the timer ends.'),
  ('Bark Detective', 'Visit three different trees and compare their bark with your fingertips.'),
  ('Barefoot Minute', 'Find grass, take your shoes off, and stand still for one full minute. Then walk a slow loop.'),
  ('Cloud Namer', 'Lie or sit somewhere outside and give names to three clouds before they drift apart.'),
];

const _darkQuests = [
  ('Night Sounds Census', 'Step out to a safe, lit spot. Close your eyes and count five distinct sounds.'),
  ('Star Hunt', 'Go outside, let your eyes adjust for two minutes, then find the brightest star or planet.'),
  ('Doorstep Breather', 'Stand at your doorstep or balcony and take ten slow breaths of the night air.'),
];
