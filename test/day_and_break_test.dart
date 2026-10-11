import 'package:flutter_test/flutter_test.dart';
import 'package:savanna_grass/domain/active_break.dart';
import 'package:savanna_grass/domain/grass_debt.dart';
import 'package:savanna_grass/domain/local_day.dart';
import 'package:savanna_grass/domain/outdoor_log.dart';
import 'package:savanna_grass/domain/reminder_plan.dart';

void main() {
  group('local days', () {
    test('a break across midnight is split between the two days', () {
      final b = LoggedBreak(
        start: DateTime(2026, 10, 11, 23, 50),
        end: DateTime(2026, 10, 12, 0, 10),
        title: 'x',
      );
      expect(b.secondsOn(DateTime(2026, 10, 11)), 600);
      expect(b.secondsOn(DateTime(2026, 10, 12, 15)), 600); // any time on the day
      expect(b.secondsOn(DateTime(2026, 10, 13)), 0);
    });

    test('the week credits each side of midnight to its own day', () {
      final w = OutdoorWeek.from([
        LoggedBreak(start: DateTime(2026, 10, 11, 23, 50), end: DateTime(2026, 10, 12, 0, 10), title: 'x'),
      ], DateTime(2026, 10, 12, 9));
      expect(w.minutes.sublist(5), [10, 10]);
    });

    test('dates are keyed and stepped by the calendar, across a month end', () {
      expect(dateKey(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
      expect(addDays(DateTime(2026, 10, 31), 1), DateTime(2026, 11, 1));
      expect(addDays(DateTime(2026, 3, 2), -6), DateTime(2026, 2, 24));
    });
  });

  group('active break', () {
    final start = DateTime(2026, 10, 12, 18);
    final b = ActiveBreak(id: 'id-1', title: 'Sky Survey', steps: 'Look up.', minutes: 10, start: start);

    test('is logged as at most three hours, however long it ran', () {
      expect(b.endAt(start.add(const Duration(minutes: 25))), start.add(const Duration(minutes: 25)));
      expect(b.endAt(start.add(const Duration(hours: 14))), start.add(ActiveBreak.maxLength));
    });

    test('a clock set back before the start is a mis-tap, not negative time', () {
      expect(b.endAt(start.subtract(const Duration(hours: 1))), start);
      expect(b.isTooShort(start.subtract(const Duration(hours: 1))), isTrue);
      expect(b.isTooShort(start.add(const Duration(seconds: 59))), isTrue);
      expect(b.isTooShort(start.add(const Duration(minutes: 1))), isFalse);
    });

    test('survives a round trip through storage, note included', () {
      final back = ActiveBreak.fromJson(b.withNote('two hawks').toJson());
      expect(back.id, 'id-1');
      expect(back.start, start);
      expect(back.minutes, 10);
      expect(back.note, 'two hawks');
      expect(back.targetAt, start.add(const Duration(minutes: 10)));
    });
  });

  group('daily nudges', () {
    const settings = ReminderSettings(dailyHour: 17, dailyMinute: 30);
    const owing = GrassDebt(owedMinutes: 30, paidMinutes: 10);
    const paid = GrassDebt(owedMinutes: 30, paidMinutes: 30);

    test('books a week ahead, today with the debt it last saw', () {
      final plan = planDailyNudges(
          now: DateTime(2026, 10, 12, 9), settings: settings, debt: owing, breakActive: false);
      expect(plan, hasLength(nudgeDaysAhead));
      expect(plan.first.at, DateTime(2026, 10, 12, 17, 30));
      expect(plan.first.title, contains('20 min'));
      expect(plan.last.at, DateTime(2026, 10, 18, 17, 30));
      expect(plan.map((r) => r.slot), [0, 1, 2, 3, 4, 5, 6]);
    });

    test('skips today once it has passed, is paid, or a break is running', () {
      for (final (now, debt, active) in [
        (DateTime(2026, 10, 12, 18), owing, false),
        (DateTime(2026, 10, 12, 9), paid, false),
        (DateTime(2026, 10, 12, 9), owing, true),
      ]) {
        final plan = planDailyNudges(now: now, settings: settings, debt: debt, breakActive: active);
        expect(plan.first.at, DateTime(2026, 10, 13, 17, 30));
        expect(plan, hasLength(nudgeDaysAhead - 1));
      }
    });

    test('unknown numbers get the general nudge; off means nothing', () {
      final plan =
          planDailyNudges(now: DateTime(2026, 10, 12, 9), settings: settings, debt: null, breakActive: false);
      expect(plan.first.title, 'How is your grass debt?');
      expect(
        planDailyNudges(
            now: DateTime(2026, 10, 12, 9),
            settings: settings.copyWith(daily: false),
            debt: owing,
            breakActive: false),
        isEmpty,
      );
    });

    test('settings read back with defaults for anything missing', () {
      final s = ReminderSettings.fromJson({'dailyHour': 8});
      expect((s.daily, s.dailyHour, s.dailyMinute, s.breakAlarm), (true, 8, 30, true));
    });
  });
}
