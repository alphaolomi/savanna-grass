import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../domain/active_break.dart';
import '../persona.dart';
import 'theme.dart';
import 'widgets.dart';

/// The break itself. Calm on purpose: one ring, one instruction — the phone's
/// job now is to go back in a pocket.
///
/// Everything it shows comes from [AppState.activeBreak], which is saved on
/// the phone, so the timer is still right after Android kills the app, the
/// phone reboots, or the person comes back tomorrow.
class BreakScreen extends StatefulWidget {
  const BreakScreen({super.key, required this.state});

  final AppState state;

  @override
  State<BreakScreen> createState() => _BreakScreenState();
}

class _BreakScreenState extends State<BreakScreen> {
  late final ActiveBreak _break = widget.state.activeBreak!;
  late final _note = TextEditingController(text: _break.note);
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

  Duration get _elapsed {
    final e = widget.state.now.difference(_break.start);
    return e.isNegative ? Duration.zero : e;
  }

  Duration get _target => Duration(minutes: _break.minutes);

  Future<void> _finish() async {
    setState(() => _saving = true);
    final minutes = _break.endAt(widget.state.now).difference(_break.start).inMinutes;
    final outcome = await widget.state.finishBreak();
    rootMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Text(switch (outcome) {
        BreakOutcome.tooShort => 'Under a minute — not logged.',
        BreakOutcome.synced => 'Logged to SavannaTime: $minutes min outside. ${Twiga.name} is proud of you.',
        BreakOutcome.queued => 'Saved on this device — it counts already and will sync when you are online.',
      }),
    ));
    if (mounted) setState(() => _saving = false);
  }

  /// Throwing away real time outside takes a second tap.
  Future<void> _cancel() async {
    if (_elapsed >= ActiveBreak.minLength) {
      final minutes = _elapsed.inMinutes;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard this break?'),
          content: Text('$minutes min outside will not be logged.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep timing')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
          ],
        ),
      );
      if (discard != true) return;
    }
    await widget.state.cancelBreak();
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
    final overCap = _elapsed > ActiveBreak.maxLength;

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
                      tooltip: 'Cancel break',
                      onPressed: _saving ? null : _cancel,
                      icon: Icon(Icons.close, color: s.onHero),
                    ),
                  ),
                  Text(_break.title,
                      textAlign: TextAlign.center,
                      style: t.textTheme.headlineSmall?.copyWith(color: s.onHero)),
                  const SizedBox(height: 8),
                  Text(_break.steps,
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
                    overCap
                        ? 'Over ${ActiveBreak.maxLength.inHours} hours — this break will be logged as '
                            '${ActiveBreak.maxLength.inHours} h, the most one break counts for.'
                        : done
                            ? 'Quest time reached. Stay out as long as you like.'
                            : 'Phone in pocket. Eyes up. The timer keeps going with the app closed.',
                    textAlign: TextAlign.center,
                    style: t.textTheme.titleMedium?.copyWith(color: s.onHero),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _note,
                    maxLength: 140,
                    onChanged: widget.state.updateBreakNote,
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
                    onPressed: _saving ? null : _cancel,
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
