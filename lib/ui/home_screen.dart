import 'package:flutter/material.dart';

import '../app_state.dart';
import '../config.dart';
import '../domain/quest.dart';
import 'break_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Savanna Grass'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'out') state.signOut();
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(state.email ?? '')),
              const PopupMenuItem(value: 'out', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (state.loadError != null) _Banner(state.loadError!),
            if (state.pending.isNotEmpty)
              _Banner('${state.pending.length} outdoor break(s) waiting to sync — '
                  'they already count. Pull to retry.'),
            _DebtCard(state: state),
            const SizedBox(height: 12),
            _ModelCard(state: state),
            const SizedBox(height: 12),
            _QuestCard(state: state),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
          child: Padding(padding: const EdgeInsets.all(12), child: Text(text)),
        ),
      );
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final debt = state.debt;
    final day = state.day;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 112,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: debt.progress,
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    backgroundColor: t.colorScheme.surfaceContainerHighest,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          debt.isPaid ? '✓' : '${debt.remainingMinutes}',
                          style: t.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(debt.isPaid ? 'paid' : 'min owed',
                            style: t.textTheme.labelSmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Grass debt', style: t.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    state.loading && state.loadedAt == null
                        ? 'Reading SavannaTime…'
                        : '${formatDuration(day.totalSeconds)} on screens today\n'
                            '${formatDuration(day.distractingSeconds)} of it distracting\n'
                            '${formatDuration(state.outdoorSeconds)} outside so far',
                    style: t.textTheme.bodyMedium
                        ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pulse ${day.pulse ?? '—'}',
                    style: t.textTheme.labelLarge,
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

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final (icon, title, body) = switch (state.modelStatus) {
      ModelStatus.checking => (Icons.hourglass_empty, 'Checking for ${Config.modelLabel}…', null),
      ModelStatus.missing => (
          Icons.download,
          'Download ${Config.modelLabel} (~550 MB, once)',
          'Quests are written by an open-weight model running on this phone. '
              'Your screen time never leaves the device for the AI. Until then, '
              'you get hand-written quests.'
        ),
      ModelStatus.downloading => (Icons.downloading, 'Downloading ${Config.modelLabel}…', null),
      ModelStatus.ready => (Icons.memory, '${Config.modelLabel} ready · on-device', 'Works offline. No AI vendor sees your day.'),
      ModelStatus.failed => (Icons.error_outline, 'Model unavailable', state.modelError),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: t.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: t.textTheme.titleSmall)),
            ]),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body,
                  style: t.textTheme.bodySmall
                      ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            ],
            if (state.modelStatus == ModelStatus.downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: state.downloadPercent / 100),
              const SizedBox(height: 4),
              Text('${state.downloadPercent}%', style: t.textTheme.labelSmall),
            ],
            if (state.modelStatus case ModelStatus.missing || ModelStatus.failed) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: state.downloadModel,
                child: Text(state.modelStatus == ModelStatus.failed ? 'Retry download' : 'Download on Wi-Fi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final quest = state.quest;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Where are you?', style: t.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<Setting>(
              segments: const [
                ButtonSegment(value: Setting.home, label: Text('Home'), icon: Icon(Icons.home_outlined)),
                ButtonSegment(value: Setting.work, label: Text('Work'), icon: Icon(Icons.work_outline)),
                ButtonSegment(value: Setting.city, label: Text('Out'), icon: Icon(Icons.location_city)),
              ],
              selected: {state.setting},
              onSelectionChanged: (s) => state.chooseSetting(s.first),
            ),
            const SizedBox(height: 20),
            if (state.writing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    state.modelStatus == ModelStatus.ready
                        ? '${Config.modelLabel} is thinking, on your phone…'
                        : 'Picking a quest…',
                    style: t.textTheme.bodySmall,
                  ),
                ]),
              )
            else if (quest != null) ...[
              Row(children: [
                Expanded(child: Text(quest.title, style: t.textTheme.headlineSmall)),
                Chip(label: Text('${quest.minutes} min')),
              ]),
              const SizedBox(height: 8),
              Text(quest.steps, style: t.textTheme.bodyLarge),
              if (quest.why.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(quest.why,
                    style: t.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: t.colorScheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 12),
              Text(
                quest.source == QuestSource.gemma
                    ? 'Written on-device by ${Config.modelLabel}'
                    : 'Hand-written quest (${state.writer.lastFallbackReason ?? 'offline'})',
                style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.primary),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.park),
                label: const Text("I'm going outside"),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BreakScreen(state: state, quest: quest),
                )),
              ),
              TextButton(
                onPressed: state.writeQuest,
                child: const Text('Another one'),
              ),
            ] else
              FilledButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: Text(state.debt.isPaid ? 'Bonus quest' : 'Give me a quest'),
                onPressed: state.writeQuest,
              ),
          ],
        ),
      ),
    );
  }
}
