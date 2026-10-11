import 'package:flutter/material.dart';

import '../api/savanna_api.dart';
import '../app_state.dart';
import '../config.dart';
import '../domain/local_day.dart';
import '../domain/profile.dart';
import '../persona.dart';
import 'reminders_sheet.dart';
import 'signed_in_page.dart';
import 'theme.dart';
import 'week_screen.dart';
import 'widgets.dart';

/// The person's own page: their SavannaTime account, their week outside, and
/// everything about how this app behaves on this phone.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.state});

  final AppState state;

  static Future<void> open(BuildContext context, AppState state) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(state: state)));

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  @override
  void initState() {
    super.initState();
    // The name may have been changed on the web since this session loaded it.
    widget.state.loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return SignedInPage(
      state: widget.state,
      builder: (context) {
        final state = widget.state;
        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: () => Future.wait([state.loadProfile(), state.refresh()]),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      if (state.profileError != null && state.profile == null) ...[
                        InfoBanner(icon: Icons.cloud_off, text: state.profileError!),
                        const SizedBox(height: 12),
                      ],
                      _Header(state: state),
                      const SizedBox(height: 12),
                      _WeekStats(state: state),
                      const SizedBox(height: 20),
                      const _SectionLabel('Account'),
                      _AccountCard(state: state),
                      const SizedBox(height: 20),
                      const _SectionLabel('On this phone'),
                      _PhoneCard(state: state),
                      const SizedBox(height: 20),
                      const _SectionLabel('Privacy'),
                      const _PrivacyCard(),
                      const SizedBox(height: 24),
                      _SignOutButton(state: state),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(text.toUpperCase(),
          style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant, letterSpacing: 1.1)),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final AppState state;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = Savanna.of(context);
    final p = state.profile;
    final email = p?.email ?? state.email ?? '';
    final initial = p?.initial ?? (email.isEmpty ? '?' : email.substring(0, 1).toUpperCase());
    final details = [
      if (p != null) 'Member since ${_months[p.createdAt.month - 1]} ${p.createdAt.year}',
      if (p?.roleLabel != null) p!.roleLabel!,
    ].join(' · ');

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
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: s.ringTrack,
            foregroundColor: s.onHero,
            child: Text(initial, style: t.textTheme.headlineMedium?.copyWith(color: s.onHero, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p == null)
                  Text('Loading your account…', style: t.textTheme.titleLarge?.copyWith(color: s.onHeroMuted))
                else if (p.name == null)
                  InkWell(
                    onTap: () => _editName(context, state),
                    child: Text('Add your name',
                        style: t.textTheme.titleLarge?.copyWith(
                          color: s.onHero,
                          decoration: TextDecoration.underline,
                          decorationColor: s.onHeroMuted,
                        )),
                  )
                else
                  Text(p.name!, style: t.textTheme.titleLarge?.copyWith(color: s.onHero, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(email, style: t.textTheme.bodyMedium?.copyWith(color: s.onHeroMuted)),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(details, style: t.textTheme.bodySmall?.copyWith(color: s.onHeroMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStats extends StatelessWidget {
  const _WeekStats({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => WeekScreen.open(context, state),
        child: _stats(context),
      );

  Widget _stats(BuildContext context) {
    final week = state.week;
    final weekStart = addDays(state.today, -6);
    final breaks = state.breaks.where((b) => !b.end.isBefore(weekStart)).length;
    final debt = state.debt;
    return Row(
      children: [
        _Stat(icon: Icons.park_outlined, value: '${week.totalMinutes}', label: 'min outside\nthis week'),
        _Stat(
          icon: Icons.local_fire_department_outlined,
          value: '${week.streak}',
          // A streak day is one with 5+ min outside (OutdoorWeek.streakMinutes).
          label: 'day\nstreak',
        ),
        _Stat(icon: Icons.directions_walk, value: '$breaks', label: breaks == 1 ? 'break\nthis week' : 'breaks\nthis week'),
        _Stat(
          icon: Icons.check_circle_outline,
          value: state.loadedAt == null ? '—' : (debt.isPaid ? '✓' : '${debt.remainingMinutes}'),
          label: debt.isPaid ? 'debt paid\ntoday' : 'min of debt\nleft today',
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            children: [
              Icon(icon, size: 20, color: t.colorScheme.primary),
              const SizedBox(height: 4),
              Text(value, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = state.profile;
    final mismatch = p == null ? null : zoneMismatch(p.timezone, state.now);
    final accountOffset = p == null ? null : zoneOffset(p.timezone, state.now);
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Name'),
            subtitle: Text(p == null ? '…' : (p.name ?? 'Not set — shown in greetings and on teams')),
            trailing: const Icon(Icons.edit_outlined),
            enabled: p != null,
            onTap: () => _editName(context, state),
          ),
          ListTile(
            leading: const Icon(Icons.alternate_email),
            title: const Text('Email'),
            subtitle: Text(p?.email ?? state.email ?? '…'),
          ),
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('Time zone'),
            subtitle: Text(p == null
                ? '…'
                : '${p.timezone}${accountOffset == null ? '' : ' (${formatOffset(accountOffset)})'} — '
                    'SavannaTime counts your days in this zone'),
          ),
          if (mismatch != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.schedule, color: t.colorScheme.onErrorContainer, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This phone is on ${formatOffset(mismatch.phone)}, your account on '
                        '${formatOffset(mismatch.account)}. Your days start at different hours here and '
                        'in SavannaTime, so time near midnight can land on a different day. Set your '
                        'time zone in SavannaTime\'s settings on the web to match.',
                        style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhoneCard extends StatelessWidget {
  const _PhoneCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final r = state.reminderSettings;
    final reminders = [
      if (r.daily) 'daily nudge at ${TimeOfDay(hour: r.dailyHour, minute: r.dailyMinute).format(context)}',
      if (r.breakAlarm) 'quest-time alarm',
    ];
    final twiga = switch (state.modelStatus) {
      ModelStatus.ready => 'On this phone · works offline',
      ModelStatus.downloading => 'Downloading… ${state.downloadPercent}%',
      ModelStatus.checking => 'Checking…',
      ModelStatus.missing => 'Not downloaded yet · ${Config.modelSizeMb} MB',
      ModelStatus.failed => 'Could not load — quests use the built-in writer',
    };
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Theme'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {state.themeMode},
                onSelectionChanged: (v) => state.setThemeMode(v.single),
              ),
            ),
          ),
          if (state.reminders.supported)
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Reminders'),
              subtitle: Text(reminders.isEmpty ? 'Off' : reminders.join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showRemindersSheet(context, state),
            ),
          ListTile(
            leading: const TwigaAvatar(size: 28),
            title: Text(Twiga.name),
            subtitle: Text(twiga),
            trailing: state.modelStatus == ModelStatus.missing || state.modelStatus == ModelStatus.failed
                ? TextButton(onPressed: state.downloadModel, child: const Text('Download'))
                : null,
          ),
          if (state.pending.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Waiting to sync'),
              subtitle: Text('${state.pending.length} break${state.pending.length == 1 ? '' : 's'} '
                  'saved on this phone — they already count.'),
              trailing: TextButton(onPressed: state.refresh, child: const Text('Sync now')),
            ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text('${Twiga.name} runs on this phone'),
            subtitle: const Text('Your screen time is turned into quests here, offline. '
                'It is never sent to an AI service.'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About & licences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Savanna Grass',
              applicationLegalese: 'Companion to SavannaTime. MIT licensed.\n'
                  'Twiga runs on this device; your screen time never leaves it for the AI.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('Time outside is saved to your SavannaTime account as time entries '
                'starting with “🌿 Touch grass”, so it shows on the web dashboard too.',
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.state});
  final AppState state;

  Future<void> _signOut(BuildContext context) async {
    final unsynced = state.pending.length;
    final running = state.activeBreak != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text([
          if (unsynced > 0)
            '$unsynced break${unsynced == 1 ? ' has' : 's have'} not reached SavannaTime yet and will be lost.',
          if (running) 'The break being timed will be discarded.',
          if (unsynced == 0 && !running) 'Your time outside is safe in SavannaTime.',
        ].join(' ')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay signed in')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) await state.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.colorScheme.error,
        side: BorderSide(color: t.colorScheme.error.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      icon: const Icon(Icons.logout),
      label: const Text('Sign out'),
      onPressed: () => _signOut(context),
    );
  }
}

Future<void> _editName(BuildContext context, AppState state) => showDialog<void>(
      context: context,
      builder: (_) => _NameDialog(state: state),
    );

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.state});
  final AppState state;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.state.profile?.name ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.state.setName(_name.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ApiException ? e.message : "You're offline — try again when you're connected.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saving ? null : _save(),
            decoration: InputDecoration(
              hintText: 'What should ${Twiga.name} call you?',
              errorText: _error,
            ),
          ),
          Text('Saved to your SavannaTime account. Leave it empty to remove it.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
