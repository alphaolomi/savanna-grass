import 'screen_day.dart';

/// Grass debt: how many minutes outside today's screen time has earned.
///
/// Deterministic on purpose (SavannaTime TRD D3): the *number* is a formula a
/// person can check by hand, and the model only writes the invitation to go
/// pay it off. The rule:
///
/// * every hour on screens owes [minutesPerScreenHour] minutes outside;
/// * distracting time (levels -1 and -2) counts [distractingWeight] times,
///   because an hour of doomscrolling is not an hour of deep work;
/// * minutes already spent outside today are paid off;
/// * the debt is capped at [dailyCap] so a long workday never asks for the
///   impossible.
class GrassDebt {
  const GrassDebt({
    required this.owedMinutes,
    required this.paidMinutes,
  });

  static const minutesPerScreenHour = 10;
  static const distractingWeight = 1.5;
  static const dailyCap = 60;

  final int owedMinutes;
  final int paidMinutes;

  int get remainingMinutes =>
      (owedMinutes - paidMinutes).clamp(0, owedMinutes);

  /// 0..1 — how much of today's debt is paid off. A day with no debt is paid.
  double get progress =>
      owedMinutes == 0 ? 1 : (paidMinutes / owedMinutes).clamp(0, 1).toDouble();

  bool get isPaid => remainingMinutes == 0;

  factory GrassDebt.compute(ScreenDay day, {required int outdoorSeconds}) {
    final distracting = day.distractingSeconds.clamp(0, day.totalSeconds);
    final weightedSeconds =
        (day.totalSeconds - distracting) + distracting * distractingWeight;
    final owed = (weightedSeconds / 3600 * minutesPerScreenHour).round();
    return GrassDebt(
      owedMinutes: owed.clamp(0, dailyCap),
      paidMinutes: outdoorSeconds ~/ 60,
    );
  }
}
