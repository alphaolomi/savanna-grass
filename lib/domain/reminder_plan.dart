import 'grass_debt.dart';
import 'local_day.dart';

/// What the person has asked to be reminded about. Kept on the phone, and
/// kept across sign-outs, like the theme.
class ReminderSettings {
  const ReminderSettings({
    this.daily = true,
    this.dailyHour = 17,
    this.dailyMinute = 30,
    this.breakAlarm = true,
  });

  /// One nudge a day about the grass debt.
  final bool daily;
  final int dailyHour;
  final int dailyMinute;

  /// Ring when a break reaches its quest time, and check in if it is still
  /// running long after.
  final bool breakAlarm;

  ReminderSettings copyWith({bool? daily, int? dailyHour, int? dailyMinute, bool? breakAlarm}) =>
      ReminderSettings(
        daily: daily ?? this.daily,
        dailyHour: dailyHour ?? this.dailyHour,
        dailyMinute: dailyMinute ?? this.dailyMinute,
        breakAlarm: breakAlarm ?? this.breakAlarm,
      );

  Map<String, dynamic> toJson() => {
        'daily': daily,
        'dailyHour': dailyHour,
        'dailyMinute': dailyMinute,
        'breakAlarm': breakAlarm,
      };

  factory ReminderSettings.fromJson(Map<String, dynamic> j) {
    const d = ReminderSettings();
    return ReminderSettings(
      daily: j['daily'] as bool? ?? d.daily,
      dailyHour: (j['dailyHour'] as num?)?.toInt() ?? d.dailyHour,
      dailyMinute: (j['dailyMinute'] as num?)?.toInt() ?? d.dailyMinute,
      breakAlarm: j['breakAlarm'] as bool? ?? d.breakAlarm,
    );
  }
}

/// One scheduled notification, compared by value so an unchanged plan is not
/// re-sent to the OS on every refresh.
class PlannedReminder {
  const PlannedReminder({required this.slot, required this.at, required this.title, required this.body});

  /// 0 for today, 1 for tomorrow, … — the notification id is derived from it.
  final int slot;
  final DateTime at;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.slot == slot &&
      other.at == at &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(slot, at, title, body);

  @override
  String toString() => 'PlannedReminder($slot, $at, $title)';
}

/// How many days of daily nudges are booked ahead. The OS fires them with the
/// app closed, so a week of them keeps nudging someone who has not opened the
/// app in days; each launch re-plans the week.
const nudgeDaysAhead = 7;

/// The daily nudges for the next [nudgeDaysAhead] days.
///
/// The phone cannot ask SavannaTime for the debt at the moment a scheduled
/// notification fires, so today's nudge is written from the last numbers the
/// app saw ([debt], null when it has none for today). Debt only grows with
/// screen time, and every break is logged through this app, which re-plans
/// when one ends — so today's figure is a floor, and is worded as one. Later
/// days get a general nudge.
///
/// Today is skipped once the debt is paid, and while a break is running.
List<PlannedReminder> planDailyNudges({
  required DateTime now,
  required ReminderSettings settings,
  required GrassDebt? debt,
  required bool breakActive,
}) {
  if (!settings.daily) return const [];
  final today = localDay(now);
  final plan = <PlannedReminder>[];
  for (var i = 0; i < nudgeDaysAhead; i++) {
    final d = addDays(today, i);
    final at = DateTime(d.year, d.month, d.day, settings.dailyHour, settings.dailyMinute);
    if (!at.isAfter(now)) continue;
    if (i == 0) {
      if (breakActive) continue;
      if (debt != null && debt.isPaid && debt.owedMinutes > 0) continue;
      if (debt != null && !debt.isPaid) {
        plan.add(PlannedReminder(
          slot: i,
          at: at,
          title: 'At least ${debt.remainingMinutes} min of grass debt left',
          body: 'Twiga has a quest ready. Ten minutes outside before the day is done?',
        ));
        continue;
      }
    }
    plan.add(PlannedReminder(
      slot: i,
      at: at,
      title: 'How is your grass debt?',
      body: 'See what today\'s screen time owes, and let Twiga plan a way outside.',
    ));
  }
  return plan;
}
