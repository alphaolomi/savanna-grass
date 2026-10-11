import 'package:flutter/material.dart';

import '../app_state.dart';
import '../config.dart';
import '../domain/outdoor_log.dart';
import '../domain/quest.dart';
import '../persona.dart';
import 'profile_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: state.refresh,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _Header(state: state),
                  const SizedBox(height: 12),
                  if (state.loadError != null) ...[
                    InfoBanner(icon: Icons.cloud_off, text: state.loadError!),
                    const SizedBox(height: 12),
                  ],
                  if (state.pending.isNotEmpty) ...[
                    InfoBanner(
                      icon: Icons.sync,
                      text: '${state.pending.length} break${state.pending.length == 1 ? '' : 's'} '
                          'saved on this device — they already count, and will sync when you are online.',
                    ),
                    const SizedBox(height: 12),
                  ],
                  _DebtHero(state: state),
                  const SizedBox(height: 12),
                  if (state.modelStatus != ModelStatus.ready &&
                      state.modelStatus != ModelStatus.checking) ...[
                    _TwigaSetupCard(state: state),
                    const SizedBox(height: 12),
                  ],
                  _QuestCard(state: state),
                  const SizedBox(height: 12),
                  _WeekCard(week: state.week),
                  const SizedBox(height: 12),
                  _TodayCard(breaks: state.todayBreaks, today: state.today),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The header greeting for [hour], with the person's first name if known.
/// The name goes inside a question ("Still up, Amani?"), not after it.
String greeting(int hour, String? name) {
  final n = (name == null || name.isEmpty) ? '' : ', $name';
  if (hour < 5) return 'Still up$n?';
  if (hour < 12) return 'Good morning$n';
  if (hour < 17) return 'Good afternoon$n';
  return 'Good evening$n';
}

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final AppState state;


  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final (icon, label) = switch (state.themeMode) {
      ThemeMode.system => (Icons.brightness_auto_outlined, 'Theme: system'),
      ThemeMode.light => (Icons.light_mode_outlined, 'Theme: light'),
      ThemeMode.dark => (Icons.dark_mode_outlined, 'Theme: dark'),
    };
    final initial = state.profile?.initial ?? (state.email ?? '?').substring(0, 1).toUpperCase();
    final first = state.profile?.name?.split(' ').first;
    return Row(
      children: [
        const BrandMark(size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting(DateTime.now().hour, first), style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              Text('Savanna Grass', style: t.textTheme.titleLarge),
            ],
          ),
        ),
        IconButton(tooltip: label, onPressed: state.cycleTheme, icon: Icon(icon)),
        Semantics(
          button: true,
          label: 'Profile',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => ProfileScreen.open(context, state),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: t.colorScheme.primaryContainer,
              foregroundColor: t.colorScheme.onPrimaryContainer,
              child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }
}

class _DebtHero extends StatelessWidget {
  const _DebtHero({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = Savanna.of(context);
    final debt = state.debt;
    final day = state.day;
    final firstLoad = state.loadedAt == null;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [s.heroTop, s.heroBottom],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        children: [
          Row(
            children: [
              ProgressRing(
                size: 100,
                stroke: 9,
                value: debt.progress,
                color: s.ring,
                track: s.ringTrack,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      debt.isPaid ? '✓' : '${debt.remainingMinutes}',
                      style: t.textTheme.headlineMedium?.copyWith(color: s.onHero, fontWeight: FontWeight.w800, height: 1),
                    ),
                    Text(debt.isPaid ? 'paid' : 'min to go',
                        style: t.textTheme.labelSmall?.copyWith(color: s.onHeroMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GRASS DEBT', style: t.textTheme.labelSmall?.copyWith(color: s.onHeroMuted)),
                    const SizedBox(height: 2),
                    Text(
                      firstLoad && state.loading
                          ? 'Reading your day…'
                          : debt.isPaid
                              ? (debt.owedMinutes == 0 ? 'Nothing owed yet' : 'All paid today')
                              : '${debt.remainingMinutes} min outside to go',
                      style: t.textTheme.titleLarge?.copyWith(color: s.onHero, height: 1.15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${debt.owedMinutes} min earned by ${formatDuration(day.totalSeconds)} on screens. '
                      '10 min per hour, distracting time ×1.5.',
                      style: t.textTheme.bodySmall?.copyWith(color: s.onHeroMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeroStat(icon: Icons.desktop_windows_outlined, label: 'Screens', value: formatDuration(day.totalSeconds)),
              _HeroStat(icon: Icons.bolt_outlined, label: 'Distracting', value: formatDuration(day.distractingSeconds)),
              _HeroStat(icon: Icons.park_outlined, label: 'Outside', value: formatDuration(state.outdoorSeconds)),
              _HeroStat(icon: Icons.favorite_border, label: 'Pulse', value: day.pulse?.toString() ?? '—'),
            ],
          ),
          if (state.loading) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(minHeight: 2, color: s.ring, backgroundColor: s.ringTrack),
          ],
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = Savanna.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: s.ringTrack,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: s.onHeroMuted),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                style: t.textTheme.titleSmall?.copyWith(color: s.onHero, fontWeight: FontWeight.w700)),
            Text(label, maxLines: 1, style: t.textTheme.labelSmall?.copyWith(color: s.onHeroMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _TwigaSetupCard extends StatelessWidget {
  const _TwigaSetupCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final muted = t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant);
    const size = Config.modelSizeMb;
    final body = switch (state.modelStatus) {
      ModelStatus.downloading => [
          Text('Bringing ${Twiga.name} home…', style: t.textTheme.titleMedium),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(minHeight: 8, value: state.downloadPercent / 100),
          ),
          const SizedBox(height: 6),
          Text(
            '${state.downloadPercent}% · ${(size * state.downloadPercent / 100).round()} of $size MB · '
            'keep the app open',
            style: muted,
          ),
        ],
      ModelStatus.failed => [
          Text("${Twiga.name} couldn't make it", style: t.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('The download stopped before it finished. Check your connection and try again — '
              'classic quests still work meanwhile.', style: muted),
          const SizedBox(height: 10),
          Row(children: [
            FilledButton.tonalIcon(
              onPressed: state.downloadModel,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
            const SizedBox(width: 8),
            if (state.modelError != null) DetailsButton(details: state.modelError!),
          ]),
        ],
      _ => [
          Text('Meet ${Twiga.name}, ${Twiga.tagline}', style: t.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${Twiga.name} turns your day into small outdoor quests. It lives on this device and '
            'works offline — your screen time never leaves your phone.',
            style: muted,
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: state.downloadModel,
            icon: const Icon(Icons.download_rounded),
            label: Text('Bring ${Twiga.name} home · $size MB'),
          ),
          const SizedBox(height: 6),
          Text('One-time download, best on Wi-Fi. Until then you get classic quests.', style: muted),
        ],
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TwigaAvatar(size: 44),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body)),
          ],
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.state});
  final AppState state;

  String _sourceLine(Quest q) {
    if (q.source == QuestSource.gemma) return 'From ${Twiga.name} · made on this device';
    final r = state.writer.lastFallbackReason ?? '';
    if (r.contains('not downloaded')) return 'A classic quest · ${Twiga.name} is still on the way';
    return 'A classic quest · ${Twiga.name} was lost for words';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final quest = state.quest;
    final ready = state.modelStatus == ModelStatus.ready;
    final muted = t.colorScheme.onSurfaceVariant;
    final target = QuestContext(day: state.day, debt: state.debt, now: DateTime.now(), setting: state.setting)
        .targetMinutes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const TwigaAvatar(size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Twiga.name, style: t.textTheme.titleMedium),
                      Text(
                        ready ? 'On this device · works offline' : 'Classic quests until ${Twiga.name} arrives',
                        style: t.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                if (ready)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: t.colorScheme.primary, shape: BoxShape.circle),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<Setting>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: Setting.home, label: Text('Home'), icon: Icon(Icons.home_outlined, size: 18)),
                ButtonSegment(value: Setting.work, label: Text('Work'), icon: Icon(Icons.work_outline, size: 18)),
                ButtonSegment(value: Setting.city, label: Text('Out'), icon: Icon(Icons.location_city, size: 18)),
              ],
              selected: {state.setting},
              onSelectionChanged: (s) => state.chooseSetting(s.first),
            ),
            const SizedBox(height: 14),
            if (state.writing)
              _Thinking(ready: ready)
            else if (quest != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(quest.title, style: t.textTheme.titleLarge)),
                  const SizedBox(width: 8),
                  Pill(icon: Icons.timer_outlined, text: '${quest.minutes} min'),
                ],
              ),
              const SizedBox(height: 6),
              Text(quest.steps, style: t.textTheme.bodyLarge),
              if (quest.why.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: t.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TwigaAvatar(size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          quest.why,
                          style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(_sourceLine(quest), style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.primary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.park),
                      label: const Text("I'm going outside"),
                      onPressed: () => state.startBreak(quest),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Another one',
                    onPressed: state.writeQuest,
                    icon: const Icon(Icons.refresh),
                    style: IconButton.styleFrom(minimumSize: const Size(50, 50)),
                  ),
                ],
              ),
            ] else ...[
              Text(
                '${Twiga.name} will plan a $target-minute escape, sized to your day and where you are.',
                style: t.textTheme.bodyMedium?.copyWith(color: muted),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: Text(state.debt.isPaid && state.debt.owedMinutes > 0 ? 'Bonus quest' : 'Give me a quest'),
                onPressed: state.writeQuest,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking({required this.ready});
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final line = Twiga.thinking[DateTime.now().second % Twiga.thinking.length];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ready ? line : 'Picking a classic quest…',
              style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(minHeight: 6),
          ),
          const SizedBox(height: 12),
          for (final w in [0.9, 0.75, 0.55]) ...[
            FractionallySizedBox(
              widthFactor: w,
              alignment: Alignment.centerLeft,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: t.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week});
  final OutdoorWeek week;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final top = week.minutes.fold(30, (a, b) => b > a ? b : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('This week outside', style: t.textTheme.titleMedium)),
                if (week.streak > 0)
                  Pill(
                    icon: Icons.local_fire_department,
                    text: '${week.streak}-day streak',
                    tone: PillTone.sun,
                  ),
              ],
            ),
            Text(
              week.totalMinutes == 0
                  ? 'No time outside logged in the last 7 days yet.'
                  : '${formatDuration(week.totalMinutes * 60)} across the last 7 days',
              style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 78,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (week.minutes[i] > 0)
                              Text('${week.minutes[i]}',
                                  style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant, fontSize: 10)),
                            const SizedBox(height: 2),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: week.minutes[i] / top),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, _) => Container(
                                height: 4 + 40 * v,
                                decoration: BoxDecoration(
                                  color: i == 6
                                      ? t.colorScheme.primary
                                      : t.colorScheme.primary.withValues(alpha: week.minutes[i] > 0 ? 0.45 : 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              i == 6 ? 'Today' : _letters[week.days[i].weekday - 1],
                              style: t.textTheme.labelSmall?.copyWith(
                                color: i == 6 ? t.colorScheme.primary : t.colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.breaks, required this.today});
  final List<LoggedBreak> breaks;

  /// Local midnight: a break that began before it shows only today's share.
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final muted = t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant);
    String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Today outside', style: t.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (breaks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('No grass yet today. Your first quest is waiting.', style: muted),
              ),
            for (final b in breaks)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: t.colorScheme.primaryContainer, shape: BoxShape.circle),
                      child: Icon(Icons.park, size: 18, color: t.colorScheme.onPrimaryContainer),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.title, style: t.textTheme.titleSmall),
                          Text(
                            '${b.start.isBefore(today) ? 'Since midnight' : hm(b.start.toLocal())}'
                            ' · ${(b.secondsOn(today) / 60).round()} min'
                            '${b.pending ? ' · waiting to sync' : ' · in SavannaTime'}',
                            style: muted,
                          ),
                          if (b.note != null)
                            Text('“${b.note}”', style: muted?.copyWith(fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
