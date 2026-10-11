import 'package:flutter/material.dart';

import '../app_state.dart';
import '../persona.dart';

Future<void> showRemindersSheet(BuildContext context, AppState state) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _RemindersSheet(state: state),
    );

class _RemindersSheet extends StatefulWidget {
  const _RemindersSheet({required this.state});
  final AppState state;

  @override
  State<_RemindersSheet> createState() => _RemindersSheetState();
}

class _RemindersSheetState extends State<_RemindersSheet> with WidgetsBindingObserver {
  bool? _permitted;
  bool? _onTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Both permissions are granted in system settings, outside the app; read
  /// them again when the person comes back from there.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final r = widget.state.reminders;
    final permitted = await r.isPermitted();
    final onTime = await r.canRingOnTime();
    if (!mounted) return;
    setState(() {
      _permitted = permitted;
      _onTime = onTime;
    });
  }

  Future<void> _pickTime() async {
    final s = widget.state.reminderSettings;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.dailyHour, minute: s.dailyMinute),
      helpText: 'Daily nudge at',
    );
    if (t == null) return;
    await widget.state.updateReminders(s.copyWith(dailyHour: t.hour, dailyMinute: t.minute));
    await _check();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final state = widget.state;
    final s = state.reminderSettings;
    final time = TimeOfDay(hour: s.dailyHour, minute: s.dailyMinute).format(context);
    final muted = t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant);

    Future<void> set(Future<void> f) async {
      await f;
      await _check();
      if (mounted) setState(() {});
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Reminders', style: t.textTheme.titleLarge),
            ),
            if (_permitted == false)
              ListTile(
                leading: Icon(Icons.notifications_off_outlined, color: t.colorScheme.error),
                title: const Text('Notifications are off for Savanna Grass'),
                subtitle: const Text('Nothing below can reach you until they are on.'),
                trailing: TextButton(
                  onPressed: () => set(state.reminders.ensurePermission()),
                  child: const Text('Turn on'),
                ),
              ),
            SwitchListTile(
              secondary: const Icon(Icons.wb_twilight_outlined),
              title: const Text('Daily nudge'),
              subtitle: Text('At $time, if today still has grass debt'),
              value: s.daily,
              onChanged: (v) => set(state.updateReminders(s.copyWith(daily: v))),
            ),
            ListTile(
              enabled: s.daily,
              leading: const Icon(Icons.schedule),
              title: const Text('Nudge time'),
              trailing: Text(time, style: t.textTheme.titleMedium),
              onTap: _pickTime,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.alarm),
              title: const Text('Ring at quest time'),
              subtitle: Text('When a break reaches its target, and a check-in if '
                  '${Twiga.name} is still timing long after'),
              value: s.breakAlarm,
              onChanged: (v) => set(state.updateReminders(s.copyWith(breakAlarm: v))),
            ),
            if (s.breakAlarm && _onTime == false)
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Ring on the minute'),
                subtitle: const Text('Without "Alarms & reminders", Android may ring a few minutes late.'),
                trailing: TextButton(
                  onPressed: () => set(state.reminders.requestRingOnTime()),
                  child: const Text('Allow'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'While you are outside, the timer stays in your notifications — tap it to come back '
                'and log the break. Reminders are scheduled on this phone; nothing is sent anywhere.',
                style: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
