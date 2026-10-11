import 'package:flutter/material.dart';

import '../api/savanna_api.dart' show outdoorMarker;
import '../app_state.dart';
import '../domain/local_day.dart';
import '../domain/outdoor_log.dart';
import 'day_screen.dart';
import 'format.dart';
import 'signed_in_page.dart';
import 'theme.dart';

/// One break: when, how long, what was noticed, which day's debt it paid,
/// and whether it has reached SavannaTime yet.
class BreakDetailScreen extends StatelessWidget {
  const BreakDetailScreen({super.key, required this.state, required this.initial});

  final AppState state;

  /// The break as it was when the page opened. Shown live by id, so a break
  /// that syncs while the page is open updates in place.
  final LoggedBreak initial;

  static Future<void> open(BuildContext context, AppState state, LoggedBreak b) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BreakDetailScreen(state: state, initial: b),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SignedInPage(
      state: state,
      builder: (context) {
        final b = (initial.id == null ? null : state.breakById(initial.id!)) ?? initial;
        final t = Theme.of(context);
        final s = Savanna.of(context);
        final muted = t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant);
        final first = localDay(b.start);
        final last = localDay(b.end.subtract(const Duration(seconds: 1)));
        final days = [
          for (var d = first; !d.isAfter(last); d = addDays(d, 1))
            if (b.secondsOn(d) >= 60) d,
        ];

        return Scaffold(
          appBar: AppBar(title: const Text('Break')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [s.heroTop, s.heroBottom],
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.park, color: s.ring, size: 32),
                        const SizedBox(height: 10),
                        Text(b.title, style: t.textTheme.headlineSmall?.copyWith(color: s.onHero)),
                        const SizedBox(height: 4),
                        Text(
                          '${shortDate(b.start)} · ${timeRange(b.start, b.end)}',
                          style: t.textTheme.bodyMedium?.copyWith(color: s.onHeroMuted),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '${b.seconds ~/ 60} min outside',
                          style: t.textTheme.displaySmall?.copyWith(color: s.onHero, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('What you noticed', style: t.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                            b.note == null ? 'Nothing written down.' : '“${b.note}”',
                            style: b.note == null
                                ? muted
                                : t.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            days.length > 1 ? 'Paid toward two days' : 'Paid toward',
                            style: t.textTheme.titleMedium,
                          ),
                        ),
                        for (final d in days)
                          () {
                            final r = state.recordFor(d);
                            final share = b.secondsOn(d) ~/ 60;
                            return ListTile(
                              title: Text('${dayTitle(d, state.today)} · ${shortDate(d)}'),
                              subtitle: Text(
                                r.screenKnown
                                    ? '$share min of the ${r.debt.owedMinutes} min owed'
                                          '${r.debt.isPaid && r.debt.owedMinutes > 0 ? ' — day paid ✓' : ''}'
                                    : '$share min outside',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => DayScreen.open(context, state, d),
                            );
                          }(),
                        if (days.length > 1)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Text(
                              'It ran past midnight, so each day gets the minutes that fell on it.',
                              style: muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: Icon(b.pending ? Icons.sync : Icons.cloud_done_outlined),
                      title: Text(b.pending ? 'Saved on this phone' : 'In SavannaTime'),
                      subtitle: Text(
                        b.pending
                            ? 'It already counts here, and will sync when you are online.'
                            : 'A time entry starting “$outdoorMarker”, so it shows on the web dashboard too.',
                      ),
                      trailing: b.pending ? TextButton(onPressed: state.refresh, child: const Text('Sync now')) : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
