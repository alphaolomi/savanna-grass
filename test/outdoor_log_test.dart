import 'package:flutter_test/flutter_test.dart';
import 'package:savanna_grass/api/savanna_api.dart';
import 'package:savanna_grass/domain/outdoor_log.dart';

LoggedBreak at(DateTime start, int minutes) =>
    LoggedBreak(start: start, end: start.add(Duration(minutes: minutes)), title: 'x');

void main() {
  final now = DateTime(2026, 10, 11, 18);

  test('buckets minutes into the last seven local days, today last', () {
    final w = OutdoorWeek.from([
      at(DateTime(2026, 10, 11, 9), 20),
      at(DateTime(2026, 10, 11, 14), 10),
      at(DateTime(2026, 10, 5, 9), 15),
      at(DateTime(2026, 10, 4, 9), 99), // eight days ago: outside the window
    ], now);
    expect(w.days.first, DateTime(2026, 10, 5));
    expect(w.days.last, DateTime(2026, 10, 11));
    expect(w.minutes, [15, 0, 0, 0, 0, 0, 30]);
    expect(w.totalMinutes, 45);
  });

  test('a streak survives a today that has not started yet', () {
    final w = OutdoorWeek.from([
      at(DateTime(2026, 10, 10, 9), 10),
      at(DateTime(2026, 10, 9, 9), 6),
      at(DateTime(2026, 10, 7, 9), 30),
    ], now);
    expect(w.streak, 2);
  });

  test('a day under five minutes breaks the streak', () {
    final w = OutdoorWeek.from([
      at(DateTime(2026, 10, 11, 9), 12),
      at(DateTime(2026, 10, 10, 9), 3),
    ], now);
    expect(w.streak, 1);
  });

  test('descriptions split back into title and note', () {
    expect(parseOutdoorDescription('$outdoorMarker · Sky Survey — 9 birds'), ('Sky Survey', '9 birds'));
    expect(parseOutdoorDescription('$outdoorMarker · Sky Survey'), ('Sky Survey', null));
  });
}
