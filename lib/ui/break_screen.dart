import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../domain/quest.dart';

/// The break itself. Deliberately dull to look at: the phone's job now is to
/// go back in a pocket.
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
          ? 'Logged to SavannaTime. Grass touched. 🌿'
          : 'Saved on your phone — it will sync when you are back online.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final left = _target - _elapsed;
    final done = left <= Duration.zero;
    final shown = done ? _elapsed : left;
    final mm = shown.inMinutes.toString().padLeft(2, '0');
    final ss = (shown.inSeconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(title: Text(widget.quest.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(widget.quest.steps, style: t.textTheme.titleMedium),
            const SizedBox(height: 40),
            Text(
              '$mm:$ss',
              textAlign: TextAlign.center,
              style: t.textTheme.displayLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: done ? t.colorScheme.primary : null,
              ),
            ),
            Text(
              done ? 'Quest time reached — stay out as long as you like' : 'Phone in pocket. Eyes up.',
              textAlign: TextAlign.center,
              style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _note,
              maxLength: 140,
              decoration: const InputDecoration(
                labelText: 'What did you notice? (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text("I'm back inside"),
              onPressed: _saving ? null : _finish,
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel — not logged'),
            ),
          ],
        ),
      ),
    );
  }
}
