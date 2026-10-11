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
      expect(p, contains('Screen time today: 5h 00m'));
      expect(p, contains('YouTube (1h 00m)'));
      expect(p, contains('October afternoon'));
      expect(p, contains('about 20 minutes'));
      expect(p, contains('It is daylight.'));
    });

    test('asks for a safe, lit spot after dark', () {
      final night = QuestContext(
        day: ctx.day,
        debt: ctx.debt,
        now: DateTime(2026, 10, 11, 22),
        setting: Setting.home,
      );
      expect(buildQuestPrompt(night), contains('well-lit'));
    });
  });

  group('parseQuest', () {
    test('reads the four labelled lines', () {
      final q = parseQuest('''
TITLE: The Leaf Census
MINUTES: 15
STEPS: Walk around the block and collect three different leaves.
WHY: Five hours of screens deserve a closer look at something real.''',
          fallbackMinutes: 10)!;
      expect(q.title, 'The Leaf Census');
      expect(q.minutes, 15);
      expect(q.steps, startsWith('Walk around'));
      expect(q.why, startsWith('Five hours'));
      expect(q.source, QuestSource.gemma);
    });

    test('tolerates markdown bold, chatter and "15 minutes"', () {
      final q = parseQuest('''
Sure! Here is your quest:
**TITLE:** "Sky Watch"
**MINUTES:** 15 minutes
**STEPS:** Find a bench and watch the clouds.''', fallbackMinutes: 10)!;
      expect(q.title, 'Sky Watch');
      expect(q.minutes, 15);
      expect(q.why, '');
    });

    test('falls back to the target minutes when MINUTES is missing', () {
      final q = parseQuest('TITLE: X\nSTEPS: Go outside.', fallbackMinutes: 12)!;
      expect(q.minutes, 12);
    });

    test('returns null when the answer is unusable', () {
      expect(parseQuest('I cannot help with that.', fallbackMinutes: 10), isNull);
      expect(parseQuest('TITLE: Only a title', fallbackMinutes: 10), isNull);
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
