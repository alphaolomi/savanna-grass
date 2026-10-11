import 'package:flutter/material.dart';

import '../app_state.dart';
import '../domain/day_record.dart';
import '../domain/outdoor_log.dart';
import '../domain/quest.dart' show formatDuration;
import 'day_screen.dart';
import 'format.dart';
import 'signed_in_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// The last seven days side by side: what each day's screens earned, what
/// time outside paid back, and which days were settled.
class WeekScreen extends StatelessWidget {
  const WeekScreen({super.key, required this.state});

  final AppState state;

  static Future<void> open(BuildContext context, AppState state) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => WeekScreen(state: state)));

  @override
  Widget build(BuildContext context) {
    return SignedInPage(
      state: state,
      builder: (context) {
        final days = state.weekDays;
        final newestFirst = days.reversed.toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Last 7 days')),
          body: RefreshIndicator(
            onRefresh: state.refresh,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    if (state.loadError != null) ...[
                      InfoBanner(icon: Icons.cloud_off, text: state.loadError!),
                      const SizedBox(height: 12),
                    ],
                    _Summary(days: days, streak: state.week.streak),
                    const SizedBox(height: 12),
                    _Chart(days: days, onTap: (d) => DayScreen.open(context, state, d)),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: [
                          for (final r in newestFirst)
                            _DayRow(record: r, today: state.today, onTap: () => DayScreen.open(context, state, r.day)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.days, required this.streak});
  final List<DayRecord> days;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = Savanna.of(context);
    final known = days.where((d) => d.screenKnown).toList();
    final paid = known.where((d) => d.debt.isPaid).length;
    final outside = days.fold(0, (a, d) => a + d.outdoorSeconds);
    final screens = known.fold(0, (a, d) => a + d.screenSeconds);
    final owed = known.fold(0, (a, d) => a + d.debt.owedMinutes);

    Widget stat(String value, String label) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: t.textTheme.titleLarge?.copyWith(color: s.onHero, fontWeight: FontWeight.w800),
          ),
          Text(label, style: t.textTheme.labelSmall?.copyWith(color: s.onHeroMuted)),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [s.heroTop, s.heroBottom],
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            known.isEmpty ? 'Reading your week…' : '$paid of ${known.length} days paid',
            style: t.textTheme.titleLarge?.copyWith(color: s.onHero),
          ),
          const SizedBox(height: 4),
          Text(
            streak > 0
                ? '$streak-day streak of ${OutdoorWeek.streakMinutes}+ minutes outside'
                : 'A streak starts with ${OutdoorWeek.streakMinutes} minutes outside today',
            style: t.textTheme.bodySmall?.copyWith(color: s.onHeroMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              stat(formatDuration(outside), 'outside'),
              stat(formatDuration(screens), 'on screens'),
              stat('$owed min', 'earned'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Minutes owed and minutes outside per day, side by side.
class _Chart extends StatelessWidget {
  const _Chart({required this.days, required this.onTap});
  final List<DayRecord> days;
  final void Function(DateTime day) onTap;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    final top = days.fold(20, (m, d) {
      final v = d.debt.owedMinutes > d.outdoorMinutes ? d.debt.owedMinutes : d.outdoorMinutes;
      return v > m ? v : m;
    });
    final muted = t.textTheme.labelSmall?.copyWith(color: c.onSurfaceVariant, fontSize: 10);

    Widget bar(int minutes, Color color) => Container(
      width: 9,
      height: 4 + 86 * minutes / top,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Earned vs. paid', style: t.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 112,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < days.length; i++)
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => onTap(days[i].day),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                bar(days[i].screenKnown ? days[i].debt.owedMinutes : 0, c.outline),
                                const SizedBox(width: 3),
                                bar(days[i].outdoorMinutes, c.primary),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(i == days.length - 1 ? 'Today' : _letters[days[i].day.weekday - 1], style: muted),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              children: [
                _Key(color: c.outline, label: 'Minutes earned by screens'),
                _Key(color: c.primary, label: 'Minutes outside'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.record, required this.today, required this.onTap});
  final DayRecord record;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = record;
    final d = r.debt;
    final isToday = r.day == today;
    final (label, tone) = !r.screenKnown
        ? ('—', null)
        : d.owedMinutes == 0
        ? ('Nothing owed', PillTone.green)
        : d.isPaid
        ? ('Paid', PillTone.green)
        : ('${d.remainingMinutes} min ${isToday ? 'to go' : 'unpaid'}', PillTone.sun);
    return ListTile(
      onTap: onTap,
      title: Text('${dayTitle(r.day, today)} · ${shortDate(r.day)}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              r.screenKnown ? '${formatDuration(r.screenSeconds)} on screens' : 'Screen time unknown',
              '${r.outdoorMinutes} min outside',
            ].join(' · '),
          ),
          if (r.screenKnown && d.owedMinutes > 0) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: d.progress,
                minHeight: 4,
                color: t.colorScheme.primary,
                backgroundColor: t.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ],
      ),
      trailing: tone == null ? Text(label) : Pill(text: label, tone: tone),
    );
  }
}
