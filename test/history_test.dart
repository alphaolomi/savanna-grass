import 'package:flutter_test/flutter_test.dart';
import 'package:savanna_grass/domain/day_record.dart';
import 'package:savanna_grass/domain/grass_debt.dart';
import 'package:savanna_grass/domain/loadable.dart';
import 'package:savanna_grass/domain/outdoor_log.dart';
import 'package:savanna_grass/domain/screen_day.dart';

LoggedBreak brk(DateTime start, int minutes) =>
    LoggedBreak(start: start, end: start.add(Duration(minutes: minutes)), title: 'x');

void main() {
  group('screen day', () {
    test('an unscored day has no Pulse, even when the server says 0', () {
      final d = ScreenDay.fromSummaryJson({
        'totalSeconds': 1080,
        'scoredSeconds': 0,
        'uncategorizedSeconds': 1080,
        'secondsByLevel': {'-2': 0, '-1': 0, '0': 0, '1': 0, '2': 0},
        'pulse': 0,
        'topApps': [],
      });
      expect(d.pulse, isNull, reason: '0 would read as "as distracting as possible"');
      expect(d.uncategorizedSeconds, 1080);
    });

    test('reads apps with category and sessions, categories and the best hour', () {
      final d = ScreenDay.fromSummaryJson({
        'totalSeconds': 7200,
        'scoredSeconds': 6000,
        'uncategorizedSeconds': 1200,
        'secondsByLevel': {'-2': 1000, '2': 5000},
        'pulse': 81,
        'mostProductiveHour': 10,
        'topApps': [
          {'appName': 'Code', 'totalSeconds': 5000, 'productivity': 2, 'category': 'development', 'sessions': 14},
          {'appName': null, 'totalSeconds': 10},
        ],
        'topCategories': [
          {'category': 'development', 'totalSeconds': 5000, 'rank': 1, 'pulse': 100, 'secondsByLevel': {'2': 5000}},
        ],
      });
      expect(d.pulse, 81);
      expect(d.mostProductiveHour, 10);
      expect(d.topApps.single.category, 'development');
      expect(d.topApps.single.sessions, 14);
      expect(d.topCategories.single.secondsByLevel, {2: 5000});

      final back = ScreenDay.fromSummaryJson(d.toSummaryJson());
      expect(back.pulse, 81);
      expect(back.topApps.single.sessions, 14);
      expect(back.topCategories.single.name, 'development');
    });

    test('a day cached by 1.1 (no scored field) still knows its Pulse', () {
      final d = ScreenDay.fromSummaryJson({
        'totalSeconds': 3600,
        'secondsByLevel': {'1': 3000},
        'pulse': 75,
        'topApps': [],
      });
      expect(d.scoredSeconds, 3000);
      expect(d.uncategorizedSeconds, 600);
      expect(d.pulse, 75);
    });

    test('the timeline always has 24 hours', () {
      final hours = HourSlice.fullDay([
        HourSlice.fromJson({'hour': 9, 'totalSeconds': 1800, 'secondsByLevel': {'-1': 600, '1': 900}}),
      ]);
      expect(hours, hasLength(24));
      expect(hours[9].distractingSeconds, 600);
      expect(hours[9].productiveSeconds, 900);
      expect(hours[9].otherSeconds, 300);
      expect(hours[3].totalSeconds, 0);
    });
  });

  group('debt, worked through', () {
    test('shows the base rate and what distraction added', () {
      final d = GrassDebt.fromSeconds(screenSeconds: 3 * 3600, distractingSeconds: 3600, outdoorSeconds: 600);
      expect(d.baseMinutes, 30);
      expect(d.distractingExtraMinutes, 5);
      expect(d.owedMinutes, 35);
      expect(d.paidMinutes, 10);
      expect(d.capped, isFalse);
    });

    test('says when the daily cap took over', () {
      final d = GrassDebt.fromSeconds(screenSeconds: 8 * 3600, distractingSeconds: 2 * 3600, outdoorSeconds: 0);
      expect(d.capped, isTrue);
      expect(d.owedMinutes, GrassDebt.dailyCap);
    });
  });

  group('day records', () {
    final today = DateTime(2026, 10, 12, 15);
    final breaks = [brk(DateTime(2026, 10, 11, 23, 50), 20), brk(DateTime(2026, 10, 10, 12), 30)];
    final totals = [
      const DayTotals(date: '2026-10-11', totalSeconds: 2 * 3600, secondsByLevel: {-1: 3600}),
      const DayTotals(date: '2026-10-12', totalSeconds: 999, secondsByLevel: {}),
    ];

    test('a past day uses its daily row and its share of each break', () {
      final r = recordForDay(day: DateTime(2026, 10, 11), today: today, breaks: breaks, weekTotals: totals);
      expect(r.screenKnown, isTrue);
      expect(r.screenSeconds, 7200);
      expect(r.outdoorMinutes, 10, reason: '23:50-00:10: ten minutes before midnight');
      expect(r.debt.owedMinutes, 25);
      expect(r.breaks, hasLength(1));
    });

    test('today prefers the live summary over the daily row', () {
      const live = ScreenDay(totalSeconds: 4000, secondsByLevel: {}, pulse: null, topApps: []);
      final r = recordForDay(day: today, today: today, breaks: breaks, weekTotals: totals, todayScreen: live);
      expect(r.screenSeconds, 4000);
      expect(r.outdoorMinutes, 10, reason: 'the other ten minutes of the midnight break');
    });

    test('a loaded detail beats everything', () {
      const fresh = ScreenDay(totalSeconds: 5000, secondsByLevel: {}, pulse: null, topApps: []);
      final r = recordForDay(
        day: DateTime(2026, 10, 11),
        today: today,
        breaks: breaks,
        weekTotals: totals,
        detail: const DayDetail(screen: fresh, hours: []),
      );
      expect(r.screenSeconds, 5000);
    });

    test('a quiet day in a read week is zero; an unread week is unknown', () {
      final quiet = recordForDay(day: DateTime(2026, 10, 9), today: today, breaks: breaks, weekTotals: totals);
      expect((quiet.screenKnown, quiet.screenSeconds), (true, 0));
      final unread = recordForDay(day: DateTime(2026, 10, 9), today: today, breaks: breaks);
      expect(unread.screenKnown, isFalse);
      final older = recordForDay(day: DateTime(2026, 9, 1), today: today, breaks: breaks, weekTotals: totals);
      expect(older.screenKnown, isFalse, reason: 'outside the week that was read');
    });

    test('the week is seven days, oldest first, ending today', () {
      final w = buildWeek(today: today, breaks: breaks, weekTotals: totals);
      expect(w.map((r) => r.day.day), [6, 7, 8, 9, 10, 11, 12]);
      expect(w[4].outdoorMinutes, 30);
      expect(w.last.screenSeconds, 999);
    });
  });

  test('time outside is spread over the hours it covered', () {
    final h = outdoorSecondsByHour([brk(DateTime(2026, 10, 12, 9, 50), 25)], DateTime(2026, 10, 12));
    expect((h[9], h[10], h[11]), (600, 900, 0));
    final night = outdoorSecondsByHour([brk(DateTime(2026, 10, 11, 23, 50), 20)], DateTime(2026, 10, 12));
    expect(night[0], 600, reason: "only the new day's share");
  });

  test('a failed reload keeps the data it had', () {
    final at = DateTime(2026, 10, 12, 9);
    final l = const Loadable<int>().started().succeeded(7, at).started().failed('offline');
    expect((l.data, l.loading, l.error, l.loadedAt), (7, false, 'offline', at));
    expect(l.isStale(at.add(const Duration(minutes: 1)), const Duration(minutes: 5)), isFalse);
    expect(l.isStale(at.add(const Duration(minutes: 5)), const Duration(minutes: 5)), isTrue);
  });
}
