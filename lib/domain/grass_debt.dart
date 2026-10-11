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
    this.screenSeconds = 0,
    this.distractingSeconds = 0,
  });

  static const minutesPerScreenHour = 10;
  static const distractingWeight = 1.5;
  static const dailyCap = 60;

  final int owedMinutes;
  final int paidMinutes;

  /// The inputs, kept so the formula can be shown worked through, not just
  /// its answer.
  final int screenSeconds;
  final int distractingSeconds;

  int get remainingMinutes =>
      (owedMinutes - paidMinutes).clamp(0, owedMinutes);

  /// 0..1 — how much of today's debt is paid off. A day with no debt is paid.
  double get progress =>
      owedMinutes == 0 ? 1 : (paidMinutes / owedMinutes).clamp(0, 1).toDouble();

  bool get isPaid => remainingMinutes == 0;

  /// Every screen minute at the base rate.
  int get baseMinutes => (screenSeconds / 3600 * minutesPerScreenHour).round();

  /// What the distracting share adds on top of the base rate.
  int get distractingExtraMinutes => (_uncappedMinutes - baseMinutes).clamp(0, _uncappedMinutes);

  /// True when the day earned more than [dailyCap] and the cap took over.
  bool get capped => _uncappedMinutes > dailyCap;

  int get _uncappedMinutes {
    final distracting = distractingSeconds.clamp(0, screenSeconds);
    final weighted = (screenSeconds - distracting) + distracting * distractingWeight;
    return (weighted / 3600 * minutesPerScreenHour).round();
  }

  factory GrassDebt.compute(ScreenDay day, {required int outdoorSeconds}) => GrassDebt.fromSeconds(
        screenSeconds: day.totalSeconds,
        distractingSeconds: day.distractingSeconds,
        outdoorSeconds: outdoorSeconds,
      );

  /// The same rule from bare totals — what `/stats/daily` gives for past days.
  factory GrassDebt.fromSeconds({
    required int screenSeconds,
    required int distractingSeconds,
    required int outdoorSeconds,
  }) {
    final probe = GrassDebt(
      owedMinutes: 0,
      paidMinutes: 0,
      screenSeconds: screenSeconds,
      distractingSeconds: distractingSeconds,
    );
    return GrassDebt(
      owedMinutes: probe._uncappedMinutes.clamp(0, dailyCap),
      paidMinutes: outdoorSeconds ~/ 60,
      screenSeconds: screenSeconds,
      distractingSeconds: distractingSeconds,
    );
  }
}
