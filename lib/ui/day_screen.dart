import 'package:flutter/material.dart';

import '../app_state.dart';
import '../domain/day_record.dart';
import '../domain/grass_debt.dart';
import '../domain/local_day.dart';
import '../domain/outdoor_log.dart';
import '../domain/quest.dart' show formatDuration;
import '../domain/screen_day.dart';
import 'break_detail_screen.dart';
import 'charts.dart';
import 'format.dart';
import 'levels.dart';
import 'signed_in_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// One local day in full: how its grass debt was worked out, its hours, what
/// the screen time was spent on, and the time outside that paid it.
class DayScreen extends StatefulWidget {
  const DayScreen({super.key, required this.state, required this.day});

  final AppState state;

  /// Any time on the day; the page shows its local date.
  final DateTime day;

  static Future<void> open(BuildContext context, AppState state, DateTime day) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DayScreen(state: state, day: localDay(day)),
    ),
  );

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame: loading notifies listeners at once, and the
    // page underneath must not be marked dirty while this route builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.state.loadDetail(widget.day);
    });
  }

  Future<void> _reload() async {
    final s = widget.state;
    await Future.wait([s.loadDetail(widget.day, force: true), if (localDay(widget.day) == s.today) s.refresh()]);
  }

  @override
  Widget build(BuildContext context) {
    return SignedInPage(
      state: widget.state,
      builder: (context) {
        final state = widget.state;
        final t = Theme.of(context);
        final detail = state.detailFor(widget.day);
        final record = state.recordFor(widget.day);
        final screen = detail.data?.screen;
        final isToday = record.day == state.today;
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dayTitle(record.day, state.today)),
                Text(
                  shortDate(record.day),
                  style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          body: RefreshIndicator(
            onRefresh: _reload,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    if (detail.error != null) ...[
                      InfoBanner(icon: Icons.cloud_off, text: detail.error!),
                      const SizedBox(height: 12),
                    ],
                    if (detail.loading && !detail.hasData) ...[
                      const LinearProgressIndicator(minHeight: 2),
                      const SizedBox(height: 12),
                    ],
                    _DebtWorkedOut(record: record, isToday: isToday),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Hour by hour',
                      subtitle: screen?.mostProductiveHour == null
                          ? null
                          : 'Most productive around ${screen!.mostProductiveHour.toString().padLeft(2, '0')}:00',
                      child: detail.data == null
                          ? _Placeholder(loading: detail.loading)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HourChart(
                                  hours: detail.data!.hours,
                                  outdoorSecondsByHour: outdoorSecondsByHour(record.breaks, record.day),
                                ),
                                const SizedBox(height: 10),
                                const _ChartKey(),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'How the screen time was spent',
                      trailing: screen == null
                          ? null
                          : Pill(text: 'Pulse ${screen.pulse ?? '—'}', icon: Icons.favorite_border),
                      child: screen == null
                          ? _Placeholder(loading: detail.loading)
                          : Column(
                              children: [
                                LevelBar(
                                  secondsByLevel: screen.secondsByLevel,
                                  uncategorizedSeconds: screen.uncategorizedSeconds,
                                ),
                                const SizedBox(height: 12),
                                LevelLegend(
                                  secondsByLevel: screen.secondsByLevel,
                                  uncategorizedSeconds: screen.uncategorizedSeconds,
                                ),
                                if (screen.pulse == null && screen.totalSeconds > 0) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'No Pulse: none of this time is categorized yet. Rate apps in SavannaTime to see one.',
                                    style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ],
                            ),
                    ),
                    if (screen != null && screen.topApps.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _Section(
                        title: 'Apps',
                        child: _AppList(apps: screen.topApps),
                      ),
                    ],
                    if (screen != null && screen.topCategories.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _Section(
                        title: 'Categories',
                        child: _CategoryList(categories: screen.topCategories),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Time outside',
                      subtitle: record.outdoorSeconds == 0 ? null : '${record.outdoorMinutes} min on this day',
                      child: _BreakList(state: state, record: record, isToday: isToday),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.textTheme.titleMedium),
                      if (subtitle != null)
                        Text(subtitle!, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.loading});
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SizedBox(
      height: 60,
      child: Center(
        child: loading
            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(
                'Not loaded — pull down to try again.',
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
      ),
    );
  }
}

/// The debt formula with this day's numbers in it, line by line, so the
/// figure on the home screen is something a person can check by hand.
class _DebtWorkedOut extends StatelessWidget {
  const _DebtWorkedOut({required this.record, required this.isToday});

  final DayRecord record;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = Savanna.of(context);
    final d = record.debt;
    final known = record.screenKnown;
    final headline = !known
        ? 'Screen time not known yet'
        : d.owedMinutes == 0
        ? 'Nothing owed'
        : d.isPaid
        ? 'Paid in full'
        : '${d.remainingMinutes} min ${isToday ? 'to go' : 'left unpaid'}';

    Widget line(String label, String value, {bool strong = false, Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: (strong ? t.textTheme.titleSmall : t.textTheme.bodyMedium)?.copyWith(
                color: color ?? (strong ? s.onHero : s.onHeroMuted),
              ),
            ),
          ),
          Text(
            value,
            style: (strong ? t.textTheme.titleSmall : t.textTheme.bodyMedium)?.copyWith(
              color: color ?? s.onHero,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProgressRing(
                size: 72,
                stroke: 7,
                value: known ? d.progress : 0,
                color: s.ring,
                track: s.ringTrack,
                child: Text(
                  !known ? '—' : (d.isPaid ? '✓' : '${d.remainingMinutes}'),
                  style: t.textTheme.titleLarge?.copyWith(color: s.onHero, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GRASS DEBT', style: t.textTheme.labelSmall?.copyWith(color: s.onHeroMuted)),
                    Text(headline, style: t.textTheme.titleLarge?.copyWith(color: s.onHero, height: 1.15)),
                  ],
                ),
              ),
            ],
          ),
          if (known) ...[
            const SizedBox(height: 14),
            Divider(color: s.ringTrack, height: 1),
            const SizedBox(height: 8),
            line(
              '${formatDuration(record.screenSeconds)} on screens × ${GrassDebt.minutesPerScreenHour} min/h',
              '${d.baseMinutes} min',
            ),
            if (record.distractingSeconds > 0)
              line(
                '${formatDuration(record.distractingSeconds)} distracting counts ×${GrassDebt.distractingWeight}',
                '+${d.distractingExtraMinutes} min',
              ),
            if (d.capped) line('Capped at ${GrassDebt.dailyCap} min a day', '= ${GrassDebt.dailyCap} min'),
            line('Owed', '${d.owedMinutes} min', strong: true),
            line('Outside', '−${d.paidMinutes} min', color: s.ring),
            const SizedBox(height: 4),
            Divider(color: s.ringTrack, height: 1),
            const SizedBox(height: 4),
            line(d.isPaid ? 'Paid' : 'Left', d.isPaid ? '✓' : '${d.remainingMinutes} min', strong: true),
          ],
        ],
      ),
    );
  }
}

class _ChartKey extends StatelessWidget {
  const _ChartKey();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    final style = t.textTheme.labelSmall?.copyWith(color: c.onSurfaceVariant);
    Widget dot(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        dot(Levels.color(c, 2), 'Productive'),
        dot(Levels.color(c, 0), 'Neutral or uncategorized'),
        dot(Levels.color(c, -2), 'Distracting'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.park, size: 10, color: c.primary),
            const SizedBox(width: 4),
            Text('Outside', style: style),
          ],
        ),
      ],
    );
  }
}

class _AppList extends StatelessWidget {
  const _AppList({required this.apps});
  final List<AppTime> apps;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final top = apps.fold(1, (m, a) => a.seconds > m ? a.seconds : m);
    final muted = t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant);
    return Column(
      children: [
        for (final a in apps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Levels.color(t.colorScheme, a.productivity),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(a.name, style: t.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                    ),
                    Text(formatDuration(a.seconds), style: t.textTheme.titleSmall),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 2),
                  child: Text(
                    [
                      Levels.label(a.productivity),
                      if (a.category != null && a.category != 'uncategorized') a.category!,
                      if (a.sessions > 0) '${a.sessions} session${a.sessions == 1 ? '' : 's'}',
                    ].join(' · '),
                    style: muted,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: a.seconds / top,
                      minHeight: 4,
                      color: Levels.color(t.colorScheme, a.productivity),
                      backgroundColor: t.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories});
  final List<CategoryTime> categories;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      children: [
        for (final c in categories)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(c.name, style: t.textTheme.titleSmall)),
                    Text(formatDuration(c.seconds), style: t.textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 4),
                LevelBar(secondsByLevel: c.secondsByLevel, height: 6),
              ],
            ),
          ),
      ],
    );
  }
}

class _BreakList extends StatelessWidget {
  const _BreakList({required this.state, required this.record, required this.isToday});

  final AppState state;
  final DayRecord record;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final muted = t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant);
    if (record.breaks.isEmpty) {
      return Text(isToday ? 'No time outside yet today.' : 'No time outside logged on this day.', style: muted);
    }
    return Column(
      children: [
        for (final LoggedBreak b in record.breaks)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: t.colorScheme.primaryContainer,
              foregroundColor: t.colorScheme.onPrimaryContainer,
              child: const Icon(Icons.park, size: 20),
            ),
            title: Text(b.title),
            subtitle: Text(
              '${timeRange(b.start, b.end)} · ${b.secondsOn(record.day) ~/ 60} min'
              '${b.secondsOn(record.day) < b.seconds ? ' on this day' : ''}'
              '${b.pending ? ' · waiting to sync' : ''}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => BreakDetailScreen.open(context, state, b),
          ),
      ],
    );
  }
}
