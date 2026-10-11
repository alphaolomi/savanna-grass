import 'package:flutter_test/flutter_test.dart';
import 'package:savanna_grass/domain/grass_debt.dart';
import 'package:savanna_grass/domain/screen_day.dart';

ScreenDay day({int total = 0, int distracting = 0}) => ScreenDay(
      totalSeconds: total,
      secondsByLevel: {-2: distracting, 1: total - distracting},
      pulse: null,
      topApps: const [],
    );

void main() {
  test('no screen time owes nothing and counts as paid', () {
    final d = GrassDebt.compute(day(), outdoorSeconds: 0);
    expect(d.owedMinutes, 0);
    expect(d.isPaid, isTrue);
    expect(d.progress, 1);
  });

  test('an hour of focused work owes ten minutes', () {
    final d = GrassDebt.compute(day(total: 3600), outdoorSeconds: 0);
    expect(d.owedMinutes, 10);
    expect(d.remainingMinutes, 10);
  });

  test('distracting time counts one and a half times', () {
    final d = GrassDebt.compute(day(total: 3600, distracting: 3600), outdoorSeconds: 0);
    expect(d.owedMinutes, 15);
  });

  test('time outside pays it off and never goes negative', () {
    final d = GrassDebt.compute(day(total: 3 * 3600), outdoorSeconds: 45 * 60);
    expect(d.owedMinutes, 30);
    expect(d.remainingMinutes, 0);
    expect(d.progress, 1);
  });

  test('a marathon day is capped', () {
    final d = GrassDebt.compute(day(total: 14 * 3600, distracting: 6 * 3600),
        outdoorSeconds: 0);
    expect(d.owedMinutes, GrassDebt.dailyCap);
  });

  test('parses /stats/summary and skips the null app bucket', () {
    final s = ScreenDay.fromSummaryJson({
      'totalSeconds': 7200,
      'pulse': null,
      'secondsByLevel': {'-2': 600, '-1': 600, '0': 0, '1': 6000, '2': 0},
      'topApps': [
        {'appName': 'Code', 'totalSeconds': 5000, 'productivity': 2, 'category': 'dev', 'sessions': 3},
        {'appName': null, 'totalSeconds': 100, 'productivity': null, 'category': null, 'sessions': 1},
      ],
    });
    expect(s.distractingSeconds, 1200);
    expect(s.pulse, isNull);
    expect(s.topApps.map((a) => a.name), ['Code']);
  });
}
