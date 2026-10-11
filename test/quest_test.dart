import 'package:flutter_test/flutter_test.dart';
import 'package:savanna_grass/ai/quest_writer.dart';
import 'package:savanna_grass/domain/grass_debt.dart';
import 'package:savanna_grass/domain/quest.dart';
import 'package:savanna_grass/domain/screen_day.dart';

final ctx = QuestContext(
  day: const ScreenDay(
    totalSeconds: 5 * 3600,
    secondsByLevel: {-2: 3600},
    pulse: 62,
    topApps: [AppTime(name: 'YouTube', seconds: 3600, productivity: -2)],
  ),
  debt: const GrassDebt(owedMinutes: 25, paidMinutes: 5),
  now: DateTime(2026, 10, 11, 15, 30),
  setting: Setting.work,
);

void main() {
  group('prompt', () {
    test('carries aggregates only, with the target length', () {
      final p = buildQuestPrompt(ctx);
      expect(p, contains('Today: 5h 00m on screens, 1h 00m of it distracting.'));
      expect(p, contains('Most used: YouTube.'));
      expect(p, isNot(contains('1h 00m)'))); // app names only, no per-app times
      expect(p, contains('It is an October afternoon. It is daylight.'));
      expect(p, contains('about 20 minutes'));
      expect(p, isNot(contains('MINUTES')));
    });

    test('after dark: close, safe and lit, and no sunshine', () {
      final night = QuestContext(
        day: ctx.day,
        debt: ctx.debt,
        now: DateTime(2026, 10, 11, 22),
        setting: Setting.home,
      );
      final p = buildQuestPrompt(night);
      expect(p, contains('It is dark outside.'));
      expect(p, contains('safe and lit'));
      expect(p, contains('do not mention the sun'));
    });

    test('another quest leans on a different sense', () {
      QuestContext v(int i) => QuestContext(
          day: ctx.day, debt: ctx.debt, now: ctx.now, setting: ctx.setting, variety: i);
      expect(v(0).focus, isNot(v(1).focus));
    });
  });

  group('parseQuest', () {
    test('reads the labelled lines; the minutes are always the app\'s', () {
      final q = parseQuest('''
TITLE: The Leaf Census
MINUTES: 45
STEPS: Walk around the block and collect three different leaves.
WHY: Five hours of screens deserve a closer look at something real.''', minutes: 20)!;
      expect(q.title, 'The Leaf Census');
      expect(q.minutes, 20);
      expect(q.steps, startsWith('Walk around'));
      expect(q.why, startsWith('Five hours'));
      expect(q.source, QuestSource.gemma);
    });

    test('tolerates markdown bold, chatter and code fences', () {
      final q = parseQuest('''
Sure! Here is your quest:
```
**TITLE:** "Sky Watch"
**STEPS:** Find a bench and watch the clouds.
```''', minutes: 10)!;
      expect(q.title, 'Sky Watch');
      expect(q.why, '');
    });

    test('takes an unlabelled first line as the title, and calms ALL CAPS', () {
      final q = parseQuest('''
THE SUN-DRENCHED WALK
MINUTES: 30
STEPS: Step into the tall grass and count the falling leaves.''', minutes: 30)!;
      expect(q.title, 'The Sun-Drenched Walk');
      expect(q.steps, startsWith('Step into'));
    });

    test('folds a numbered STEPS list into one instruction', () {
      final q = parseQuest('''
TITLE: Cozy Vibes
STEPS:
1. Find a shady spot on the balcony.
2. Listen for three different birds.
WHY: Your eyes need a break.''', minutes: 10)!;
      expect(q.steps, 'Find a shady spot on the balcony. Listen for three different birds.');
      expect(q.why, 'Your eyes need a break.');
    });

    test('keeps two steps of a long list, and rejects an echoed format', () {
      final q = parseQuest('TITLE: Sky\nSTEPS:\n1. One.\n2. Two.\n3. Three.', minutes: 10)!;
      expect(q.steps, 'One. Two.');
      final inline =
          parseQuest('TITLE: X\nSTEPS: Find a corner, 2. Count leaves, 3. Breathe.', minutes: 10)!;
      expect(inline.steps, 'Find a corner, Count leaves, Breathe.');
      expect(parseQuest('TITLE: <a playful title>\nSTEPS: <what to do>', minutes: 10), isNull);
    });

    test('ignores a second, repeated answer', () {
      final q = parseQuest('TITLE: First\nSTEPS: Go out.\nTITLE: Second\nSTEPS: Stay in.', minutes: 10)!;
      expect(q.title, 'First');
      expect(q.steps, 'Go out.');
    });

    test('returns null when the answer is unusable', () {
      expect(parseQuest('', minutes: 10), isNull);
      expect(parseQuest('```\n```\n```', minutes: 10), isNull);
      expect(parseQuest('TITLE: Only a title', minutes: 10), isNull);
    });
  });

  group('LocalModelQuestWriter', () {
    test('uses the template until the model is ready', () async {
      var called = false;
      final w = LocalModelQuestWriter(
        generate: (_) async {
          called = true;
          return '';
        },
        isReady: () => false,
      );
      final q = await w.write(ctx);
      expect(called, isFalse);
      expect(q.source, QuestSource.template);
      expect(q.minutes, 20);
      expect(w.lastFallbackReason, 'model not downloaded');
    });

    test('returns the model quest when it parses', () async {
      final w = LocalModelQuestWriter(
        generate: (_) async => 'TITLE: Hi\nMINUTES: 9\nSTEPS: Go.\nWHY: Because.',
        isReady: () => true,
      );
      final q = await w.write(ctx);
      expect(q.source, QuestSource.gemma);
      expect(w.lastFallbackReason, isNull);
    });

    test('fills a missing WHY from the real numbers', () async {
      final w = LocalModelQuestWriter(
        generate: (_) async => 'TITLE: Hi\nSTEPS: Go.',
        isReady: () => true,
      );
      final q = await w.write(ctx);
      expect(q.why, '5h 00m on screens today. This pays back 20 of your 20 minutes.');
    });

    test('never fails the person when the model throws', () async {
      final w = LocalModelQuestWriter(
        generate: (_) async => throw StateError('GPU delegate missing'),
        isReady: () => true,
      );
      final q = await w.write(ctx);
      expect(q.source, QuestSource.template);
      expect(w.lastFallbackReason, contains('GPU delegate missing'));
    });
  });
}
