import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../domain/quest.dart';
import '../persona.dart';
import 'theme.dart';
import 'widgets.dart';

/// The break itself. Calm on purpose: one ring, one instruction — the phone's
/// job now is to go back in a pocket.
class BreakScreen extends StatefulWidget {
  const BreakScreen({super.key, required this.state, required this.quest});

  final AppState state;
  final Quest quest;

  @override
  State<BreakScreen> createState() => _BreakScreenState();
}

class _BreakScreenState extends State<BreakScreen> {
  final _start = DateTime.now();
  final _note = TextEditingController();
  late final Timer _tick;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    _note.dispose();
    super.dispose();
  }

  Duration get _elapsed => DateTime.now().difference(_start);
  Duration get _target => Duration(minutes: widget.quest.minutes);

  Future<void> _finish() async {
    setState(() => _saving = true);
    final end = DateTime.now();
    // Under a minute is a mis-tap, not time outside, so it is not logged.
    if (end.difference(_start).inSeconds < 60) {
      Navigator.of(context).pop();
      return;
    }
    final minutes = end.difference(_start).inMinutes;
    final synced = await widget.state.finishBreak(
      title: widget.quest.title,
      start: _start,
      end: end,
      note: _note.text,
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text(synced
          ? 'Logged to SavannaTime: $minutes min outside. ${Twiga.name} is proud of you.'
          : 'Saved on this device — it counts already and will sync when you are online.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = Savanna.of(context);
    final left = _target - _elapsed;
    final done = left <= Duration.zero;
    final shown = done ? _elapsed : left;
    final mm = shown.inMinutes.toString().padLeft(2, '0');
    final ss = (shown.inSeconds % 60).toString().padLeft(2, '0');
    final progress = (_elapsed.inSeconds / _target.inSeconds).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: s.heroBottom,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [s.heroTop, s.heroBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: s.onHero),
                    ),
                  ),
                  Text(widget.quest.title,
                      textAlign: TextAlign.center,
                      style: t.textTheme.headlineSmall?.copyWith(color: s.onHero)),
                  const SizedBox(height: 8),
                  Text(widget.quest.steps,
                      textAlign: TextAlign.center,
                      style: t.textTheme.bodyLarge?.copyWith(color: s.onHeroMuted)),
                  const SizedBox(height: 28),
                  Center(
                    child: ProgressRing(
                      size: 230,
                      stroke: 12,
                      value: progress,
                      color: done ? s.sun : s.ring,
                      track: s.ringTrack,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$mm:$ss',
                            style: t.textTheme.displayMedium?.copyWith(
                              color: s.onHero,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(done ? 'outside — keep going' : 'left',
                              style: t.textTheme.labelLarge?.copyWith(color: s.onHeroMuted)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    done ? 'Quest time reached. Stay out as long as you like.' : 'Phone in pocket. Eyes up.',
                    textAlign: TextAlign.center,
                    style: t.textTheme.titleMedium?.copyWith(color: s.onHero),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _note,
                    maxLength: 140,
                    style: TextStyle(color: s.onHero),
                    cursorColor: s.onHero,
                    decoration: InputDecoration(
                      labelText: 'What did you notice? (optional)',
                      labelStyle: TextStyle(color: s.onHeroMuted),
                      counterStyle: TextStyle(color: s.onHeroMuted),
                      fillColor: s.ringTrack,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: s.ring, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: s.onHero, foregroundColor: s.heroBottom),
                    icon: _saving
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: s.heroBottom),
                          )
                        : const Icon(Icons.check),
                    label: const Text("I'm back inside"),
                    onPressed: _saving ? null : _finish,
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: s.onHeroMuted),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel — not logged'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
