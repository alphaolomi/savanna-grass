import '../persona.dart';
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
    this.variety = 0,
  });

  final ScreenDay day;
  final GrassDebt debt;
  final DateTime now;
  final Setting setting;

  /// Which sense the quest leans on; rotates so "another one" differs.
  final int variety;

  static const focuses = [
    'sounds', 'textures you can touch', 'the sky', 'colours',
    'smells', 'things that move', 'plants and trees', 'light and shadow',
  ];

  String get focus => focuses[(variety + now.minute) % focuses.length];

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

/// The prompt for the on-device model (a 1B model, so short and firm).
///
/// The model writes words only. How long the quest lasts is the app's number
/// — today's remaining grass debt — exactly like the debt itself: a formula
/// a person can check, never a model's guess.
String buildQuestPrompt(QuestContext c) {
  final apps = c.day.topApps.take(3).map((a) => a.name).join(', ');
  final when = '${_article(_months[c.now.month - 1])} ${_months[c.now.month - 1]} ${c.partOfDay}';
  final light = c.isDark ? 'It is dark outside.' : 'It is daylight.';
  return '''
${Twiga.promptIntro}

Write ONE small outdoor quest for this person. Facts:
- Today: ${formatDuration(c.day.totalSeconds)} on screens, ${formatDuration(c.day.distractingSeconds)} of it distracting.${apps.isEmpty ? '' : ' Most used: $apps.'}
- It is $when. $light They are ${c.setting.phrase}.
- The quest takes about ${c.targetMinutes} minutes and is built around ${c.focus}.

Rules:
- It happens outdoors${c.isDark ? ', close by, somewhere safe and lit, like a doorstep, balcony or lit street' : ''}.
- No equipment, no purchases, no phone.
- Specific and sensory: something to notice, find, or count.${c.isDark ? '\n- It is night: do not mention the sun or sunshine.' : ''}

Answer in exactly three lines, nothing else:
TITLE: <a playful title, at most 6 words>
STEPS: <one or two sentences saying exactly what to do>
WHY: <one warm sentence linking it to their screen time today>''';
}

String _article(String word) => 'AEIOU'.contains(word[0]) ? 'an' : 'a';

final _label = RegExp(r'^\s*\**\s*(TITLE|MINUTES|STEPS|WHY)\s*\**\s*:\s*(.*)$',
    caseSensitive: false);
final _listMarker = RegExp(r'^\s*(?:[-*•]|\d+[.)])\s+');

/// Parses the model's answer. Returns null when the output is not usable, so
/// the caller falls back to a template rather than showing half a quest.
///
/// Small models are sloppy with format, so this is forgiving: a value may run
/// over several lines (STEPS as a numbered list), an unlabelled first line is
/// taken as the title, and an ALL-CAPS title is calmed down. A MINUTES line is
/// read past and ignored — the duration is always [minutes], the app's number.
Quest? parseQuest(String raw, {required int minutes}) {
  final fields = <String, List<String>>{};
  List<String>? current;
  String? unlabelledFirst;
  for (final line in raw.replaceAll('```', '').split('\n')) {
    final m = _label.firstMatch(line);
    if (m != null) {
      final key = m.group(1)!.toUpperCase();
      // The first answer wins: a model that repeats the format is restarting.
      current = fields.containsKey(key) ? null : (fields[key] = []);
      final rest = m.group(2)!;
      if (rest.trim().isNotEmpty) current?.add(rest);
    } else if (current != null && line.trim().isNotEmpty) {
      current.add(line);
    } else if (fields.isEmpty && unlabelledFirst == null && line.trim().isNotEmpty) {
      unlabelledFirst = line;
    }
  }
  String? field(String k, {int maxParts = 99}) {
    final parts = fields[k]
        ?.map((l) => l.replaceAll('**', '').replaceFirst(_listMarker, '').trim())
        .where((l) => l.isNotEmpty)
        .take(maxParts)
        .toList();
    return (parts == null || parts.isEmpty) ? null : parts.join(' ');
  }

  final title = field('TITLE') ?? unlabelledFirst?.replaceAll('**', '').replaceAll('#', '').trim();
  // Two steps are a quest; five are a chore list.
  final steps = field('STEPS', maxParts: 2)
      // "corner, 2. Count the leaves, 3. Feel the air" → plain prose.
      ?.replaceAll(RegExp(r'(?<=[,;]\s)\d+[.)]\s+'), '');
  if (title == null || title.isEmpty || steps == null) return null;
  // A model that echoes the format back has not written a quest.
  if ('$title $steps'.contains('<') && '$title $steps'.contains('>')) return null;
  return Quest(
    title: _calm(_trimQuotes(title)),
    minutes: minutes,
    steps: steps,
    why: field('WHY') ?? '',
    source: QuestSource.gemma,
  );
}

/// "THE SUN-DRENCHED WALK" → "The Sun-Drenched Walk". Mixed case is left alone.
String _calm(String title) {
  if (title != title.toUpperCase() || title == title.toLowerCase()) return title;
  return title.toLowerCase().splitMapJoin(
        RegExp(r"[a-z][a-z']*"),
        onMatch: (m) => m[0]![0].toUpperCase() + m[0]!.substring(1),
      );
}

/// Twiga's line when the model leaves WHY out: built from the day's real
/// numbers, so it is never wrong.
String twigaWhy(QuestContext c) {
  final screens = formatDuration(c.day.totalSeconds);
  if (c.debt.owedMinutes == 0) return 'A head start before the screens win today.';
  if (c.debt.isPaid) return "Debt's paid — this one is just for you.";
  final pays = c.targetMinutes.clamp(0, c.debt.remainingMinutes);
  return '$screens on screens today. This pays back $pays of your ${c.debt.remainingMinutes} minutes.';
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
