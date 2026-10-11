import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:uuid/uuid.dart';

import 'ai/gemma_runtime.dart';
import 'ai/quest_writer.dart';
import 'api/savanna_api.dart';
import 'domain/active_break.dart';
import 'domain/grass_debt.dart';
import 'domain/local_day.dart';
import 'domain/outdoor_log.dart';
import 'domain/quest.dart';
import 'domain/reminder_plan.dart';
import 'domain/screen_day.dart';
import 'reminders.dart';
import 'storage.dart';

enum AuthStatus { unknown, signedOut, signedIn }

enum ModelStatus { checking, missing, downloading, ready, failed }

/// How a finished break was recorded.
enum BreakOutcome {
  /// Under [ActiveBreak.minLength]: a mis-tap, not logged.
  tooShort,

  /// On the SavannaTime server.
  synced,

  /// Saved on the phone; it counts already and syncs when online.
  queued,
}

class AppState extends ChangeNotifier {
  AppState({
    required this.api,
    required this.storage,
    required this.gemma,
    this.reminders = const NoReminders(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _today = localDay(_clock());
    writer = LocalModelQuestWriter(
      generate: gemma.generate,
      isReady: () => modelStatus == ModelStatus.ready,
    );
  }

  /// Numbers older than this are re-read quietly while the app is open. The
  /// desktop tracker syncs about once a minute, so screen time moves all day.
  static const staleAfter = Duration(minutes: 5);

  /// Coming back to the app re-reads anything older than this.
  static const staleOnResume = Duration(minutes: 1);

  /// While open, how often the app checks whether the day has turned or the
  /// numbers have gone stale. Cheap: one clock read per tick.
  static const tickEvery = Duration(minutes: 1);

  final SavannaApi api;
  final Storage storage;
  final GemmaRuntime gemma;
  final Reminders reminders;
  late final LocalModelQuestWriter writer;
  final DateTime Function() _clock;

  AuthStatus auth = AuthStatus.unknown;
  String? email;
  ThemeMode themeMode = ThemeMode.system;
  ReminderSettings reminderSettings = const ReminderSettings();

  ModelStatus modelStatus = ModelStatus.checking;
  int downloadPercent = 0;
  String? modelError;

  ScreenDay day = ScreenDay.empty;
  List<LoggedBreak> _serverBreaks = [];
  List<OutdoorBreak> pending = [];
  bool loading = false;
  String? loadError;

  /// When [day] was read from the server; null when there is nothing for
  /// [today] yet.
  DateTime? loadedAt;

  Setting setting = Setting.home;
  Quest? quest;
  bool writing = false;
  int _questsWritten = 0;

  /// The break being timed right now, if any. While it is set the app shows
  /// the break screen, across restarts.
  ActiveBreak? activeBreak;

  late DateTime _today;

  /// Bumped on every sign-in and sign-out. Work that started under an older
  /// session (a refresh in flight when the person signed out) checks it and
  /// drops its results instead of writing one account's numbers into another.
  int _session = 0;

  Future<void>? _refreshing;
  bool _refreshAgain = false;
  Future<bool>? _flushing;
  Timer? _ticker;
  AppLifecycleListener? _lifecycle;
  List<PlannedReminder> _booked = const [];

  DateTime get now => _clock();

  /// Local midnight of the day the app is showing.
  DateTime get today => _today;

  /// This week's breaks: what the server has, plus anything still queued —
  /// time outside counts the moment the break ends, not when it syncs.
  List<LoggedBreak> get breaks => [
        ..._serverBreaks,
        for (final b in pending)
          LoggedBreak(start: b.start, end: b.end, title: b.title, note: b.note, pending: true),
      ]..sort((a, b) => b.start.compareTo(a.start));

  /// Breaks with any time on [today], including one that began last night.
  List<LoggedBreak> get todayBreaks => breaks.where((b) => b.secondsOn(_today) > 0).toList();

  int get outdoorSeconds => breaks.fold(0, (s, b) => s + b.secondsOn(_today));

  GrassDebt get debt => GrassDebt.compute(day, outdoorSeconds: outdoorSeconds);

  OutdoorWeek get week => OutdoorWeek.from(breaks, _today);

  // ---------------------------------------------------------------------------
  // Start-up and lifecycle

  Future<void> boot() async {
    unawaited(_checkModel());
    await _quietly(reminders.init(onOpen: onResumed));
    await restore();
  }

  /// Reads everything kept on the phone, shows it, then catches up with the
  /// server. After Android has killed the app this puts it back exactly as it
  /// was: same account, same break running, same numbers until fresher ones
  /// arrive.
  Future<void> restore() async {
    themeMode = await storage.readThemeMode();
    reminderSettings = await storage.readReminderSettings();
    final session = await storage.readSession();
    pending = await storage.readPending();
    if (session == null) {
      auth = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    api.token = session.token;
    email = session.email;
    _today = localDay(now);

    final snap = await storage.readSnapshot();
    if (snap != null) {
      _serverBreaks = snap.breaks;
      // Yesterday's screen time owes nothing today.
      if (snap.date == dateKey(_today)) {
        day = snap.day;
        loadedAt = snap.loadedAt;
      }
    }

    var b = await storage.readActiveBreak();
    // Killed after the break was queued but before it was cleared: it is
    // already logged, so it is not running any more.
    if (b != null && pending.any((p) => p.id == b!.id)) {
      await storage.clearActiveBreak();
      b = null;
    }
    activeBreak = b;
    // A reboot clears the running-timer notification; put it back.
    if (b != null) await _quietly(reminders.showBreak(b, alarm: reminderSettings.breakAlarm, now: now));

    auth = AuthStatus.signedIn;
    notifyListeners();
    _startTicker();
    await _refreshTokenIfNeeded();
    await refresh();
  }

  /// Follows the app into and out of the background. Separate from the
  /// constructor so tests can call [onResumed] and [onBackgrounded] directly.
  void attachLifecycle() {
    _lifecycle ??= AppLifecycleListener(onResume: onResumed, onHide: onBackgrounded);
  }

  /// Back in front: catch up on whatever happened while away — a new day, a
  /// token close to expiry, screen time the desktop synced meanwhile.
  void onResumed() {
    if (auth != AuthStatus.signedIn) return;
    _startTicker();
    if (checkDay()) return; // the new day's refresh is already running
    unawaited(() async {
      await _refreshTokenIfNeeded();
      if (_olderThan(staleOnResume)) await refresh(quiet: true);
    }());
  }

  /// Leaving the screen: nothing needs to tick, and anything worth keeping is
  /// written down now, because the app may not get another chance.
  void onBackgrounded() {
    _ticker?.cancel();
    _ticker = null;
    final b = activeBreak;
    if (b != null) unawaited(_quietly(storage.writeActiveBreak(b)));
    unawaited(_syncReminders());
  }

  /// Moves the app onto a new local day when the date has changed since it
  /// last looked — midnight while open, a night asleep in the background, a
  /// timezone change or a clock change. Returns true if it did.
  bool checkDay() {
    final d = localDay(now);
    if (d == _today) return false;
    _today = d;
    // Yesterday's screen time owes nothing today. The breaks stay: the week
    // needs them, and today's share of one across midnight still counts.
    day = ScreenDay.empty;
    loadedAt = null;
    loadError = null;
    // A quest written against yesterday's debt is stale; one being walked
    // right now is not.
    if (activeBreak == null) quest = null;
    notifyListeners();
    if (auth == AuthStatus.signedIn) unawaited(refresh());
    unawaited(_syncReminders());
    return true;
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(tickEvery, (_) {
      if (auth != AuthStatus.signedIn) return;
      if (checkDay()) return;
      if (_olderThan(staleAfter)) unawaited(refresh(quiet: true));
    });
  }

  bool _olderThan(Duration age) {
    final at = loadedAt;
    return at == null || now.difference(at) >= age;
  }

  bool _disposed = false;

  /// Work started before [dispose] (a quiet refresh, a flush) may still
  /// finish afterwards; it has no one left to tell.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Account

  void cycleTheme() {
    themeMode = switch (themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    unawaited(storage.writeThemeMode(themeMode));
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    final session = await api.login(email.trim(), password);
    _session++;
    api.token = session.token;
    await storage.writeSession(session);
    this.email = session.email;
    _today = localDay(now);
    auth = AuthStatus.signedIn;
    notifyListeners();
    _startTicker();
    await refresh();
  }

  Future<void> signOut() async {
    _session++;
    try {
      await api.logout();
    } catch (_) {
      // Signing out locally must work offline; the token expires on its own.
    }
    api.token = null;
    await storage.clearSession();
    _ticker?.cancel();
    _ticker = null;
    auth = AuthStatus.signedOut;
    email = null;
    day = ScreenDay.empty;
    _serverBreaks = [];
    pending = [];
    quest = null;
    activeBreak = null;
    loadedAt = null;
    loadError = null;
    loading = false;
    notifyListeners();
    await _quietly(reminders.clearBreak());
    await _syncReminders(force: true);
  }

  // ---------------------------------------------------------------------------
  // Numbers

  /// Re-reads today from the server. Calls made while one is running share it
  /// and ask for one more pass afterwards, so a pull-to-refresh during a
  /// background refresh still ends with fresh numbers. [quiet] skips the
  /// progress bar, for refreshes the person did not ask for.
  Future<void> refresh({bool quiet = false}) async {
    final running = _refreshing;
    if (running != null) {
      _refreshAgain = true;
      return running;
    }
    final run = _load(quiet: quiet);
    _refreshing = run;
    try {
      await run;
    } finally {
      _refreshing = null;
      if (_refreshAgain) {
        _refreshAgain = false;
        unawaited(refresh(quiet: true));
      }
    }
  }

  Future<void> _load({required bool quiet}) async {
    if (auth != AuthStatus.signedIn) return;
    final session = _session;
    final forDay = _today;
    if (!quiet) {
      loading = true;
      notifyListeners();
    }
    try {
      await _flushPending();
      final results = await Future.wait([
        api.today(forDay),
        api.outdoorBreaks(addDays(forDay, -6), forDay),
      ]);
      if (session != _session) return;
      if (forDay != _today) {
        // Midnight passed while this was in flight: these are yesterday's
        // numbers. Drop them and read the new day.
        _refreshAgain = true;
        return;
      }
      day = results[0] as ScreenDay;
      _serverBreaks = results[1] as List<LoggedBreak>;
      loadedAt = now;
      loadError = null;
      unawaited(_quietly(storage.writeSnapshot(Snapshot(
        date: dateKey(forDay),
        day: day,
        breaks: _serverBreaks,
        loadedAt: loadedAt!,
      ))));
    } on ApiException catch (e) {
      if (session != _session) return;
      if (e.isUnauthorized) {
        await signOut();
        return;
      }
      loadError = e.message;
    } catch (_) {
      if (session != _session) return;
      final at = loadedAt;
      loadError = at == null
          ? "You're offline — pull down to try again."
          : "You're offline — showing numbers from ${clockTime(at)}.";
    } finally {
      if (session == _session) {
        loading = false;
        notifyListeners();
        unawaited(_syncReminders());
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Quests and breaks

  void chooseSetting(Setting s) {
    setting = s;
    notifyListeners();
  }

  Future<void> writeQuest() async {
    writing = true;
    notifyListeners();
    try {
      quest = await writer.write(QuestContext(
        day: day,
        debt: debt,
        now: now,
        setting: setting,
        variety: _questsWritten++,
      ));
    } finally {
      writing = false;
      notifyListeners();
    }
  }

  /// Starts timing [q]. The break is saved before anything else, so from here
  /// on the app being killed cannot lose it.
  Future<void> startBreak(Quest q) async {
    if (activeBreak != null) return;
    final b = ActiveBreak(
      id: const Uuid().v4(),
      title: q.title,
      steps: q.steps,
      minutes: q.minutes,
      start: now,
    );
    activeBreak = b;
    notifyListeners();
    await storage.writeActiveBreak(b);
    // The first break is when a timer in the shade and an alarm earn their
    // keep, so that is when to ask for permission to notify.
    await _quietly(reminders.ensurePermission());
    await _quietly(reminders.showBreak(b, alarm: reminderSettings.breakAlarm, now: now));
    unawaited(_syncReminders());
  }

  /// The note is kept in memory as it is typed and written down when the app
  /// goes to the background or the break ends.
  void updateBreakNote(String note) {
    final b = activeBreak;
    if (b != null) activeBreak = b.withNote(note);
  }

  /// Ends the running break and records it: queued on the phone first, then
  /// sent. If the send fails the break stays queued and is retried on the
  /// next refresh — its client-generated id makes the retry land once.
  Future<BreakOutcome> finishBreak() async {
    final b = activeBreak;
    if (b == null) return BreakOutcome.tooShort;
    final at = now;
    if (b.isTooShort(at)) {
      await cancelBreak();
      return BreakOutcome.tooShort;
    }
    activeBreak = null;
    final note = b.note.trim();
    final logged = OutdoorBreak(
      id: b.id,
      title: b.title,
      start: b.start,
      end: b.endAt(at),
      note: note.isEmpty ? null : note,
    );
    if (!pending.any((p) => p.id == logged.id)) pending = [...pending, logged];
    quest = null;
    notifyListeners();
    // Queue first, clear second: a kill in between leaves a queued break and a
    // stale running one, and restore() recognises that pair.
    await storage.writePending(pending);
    await storage.clearActiveBreak();
    await _quietly(reminders.clearBreak());
    final synced = await _flushPending();
    if (synced) unawaited(refresh(quiet: true));
    unawaited(_syncReminders());
    return synced ? BreakOutcome.synced : BreakOutcome.queued;
  }

  /// Stops the running break without logging it.
  Future<void> cancelBreak() async {
    if (activeBreak == null) return;
    activeBreak = null;
    notifyListeners();
    await storage.clearActiveBreak();
    await _quietly(reminders.clearBreak());
    unawaited(_syncReminders());
  }

  // ---------------------------------------------------------------------------
  // Reminders

  Future<void> updateReminders(ReminderSettings s) async {
    reminderSettings = s;
    notifyListeners();
    await storage.writeReminderSettings(s);
    if (s.daily || s.breakAlarm) await _quietly(reminders.ensurePermission());
    final b = activeBreak;
    if (b != null) await _quietly(reminders.showBreak(b, alarm: s.breakAlarm, now: now));
    await _syncReminders(force: true);
  }

  /// Books the daily nudges for the week ahead from the latest numbers, if
  /// they changed since the last booking.
  Future<void> _syncReminders({bool force = false}) async {
    final plan = auth == AuthStatus.signedIn
        ? planDailyNudges(
            now: now,
            settings: reminderSettings,
            debt: loadedAt == null ? null : debt,
            breakActive: activeBreak != null,
          )
        : const <PlannedReminder>[];
    if (!force && listEquals(plan, _booked)) return;
    _booked = plan;
    await _quietly(reminders.setDaily(plan));
  }

  // ---------------------------------------------------------------------------
  // Model

  Future<void> downloadModel() async {
    modelStatus = ModelStatus.downloading;
    downloadPercent = 0;
    modelError = null;
    notifyListeners();
    try {
      await gemma.install(onProgress: (p) {
        downloadPercent = p;
        notifyListeners();
      });
      modelStatus = ModelStatus.ready;
    } catch (e) {
      modelStatus = ModelStatus.failed;
      modelError = '$e';
    }
    notifyListeners();
  }

  Future<void> _checkModel() async {
    try {
      if (await gemma.isInstalled()) {
        await gemma.install(); // already on disk: just marks it active
        modelStatus = ModelStatus.ready;
      } else {
        modelStatus = ModelStatus.missing;
      }
    } catch (e) {
      modelStatus = ModelStatus.failed;
      modelError = '$e';
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Sync

  /// Sends queued breaks, one flush at a time — two overlapping flushes would
  /// each move the same break into the server list and count it twice.
  /// Returns true when the queue is empty afterwards.
  Future<bool> _flushPending() async {
    while (_flushing != null) {
      await _flushing;
    }
    final run = _flush();
    _flushing = run;
    try {
      return await run;
    } finally {
      _flushing = null;
    }
  }

  Future<bool> _flush() async {
    if (pending.isEmpty) return true;
    final session = _session;
    final sent = <OutdoorBreak>[];
    for (final b in List.of(pending)) {
      try {
        await api.logOutdoorBreak(b);
        sent.add(b);
      } on ApiException catch (e) {
        if (e.isUnauthorized) break; // refresh() signs out on the 401
      } catch (_) {
        break; // offline: the rest would fail the same way
      }
    }
    if (session != _session) return false;
    if (sent.isNotEmpty) {
      final ids = {for (final b in sent) b.id};
      // Only what was sent leaves the queue; a break queued while this ran
      // stays for the next flush.
      pending = [for (final b in pending) if (!ids.contains(b.id)) b];
      // Synced breaks move to the server list right away, so the totals do
      // not dip while the follow-up refresh is in flight.
      _serverBreaks = [
        ..._serverBreaks,
        for (final b in sent) LoggedBreak(start: b.start, end: b.end, title: b.title, note: b.note),
      ];
      await storage.writePending(pending);
      notifyListeners();
    }
    return pending.isEmpty;
  }

  /// SavannaTime tokens live 7 days; renew inside the last day so an app that
  /// is opened daily — or left open for a week — never gets signed out.
  Future<void> _refreshTokenIfNeeded() async {
    final token = api.token;
    if (token == null) return;
    final left = secondsUntilExpiry(token, now);
    if (left == null || left > 24 * 3600) return;
    try {
      final fresh = await api.refresh();
      api.token = fresh;
      await storage.writeSession(Session(token: fresh, email: email ?? ''));
    } catch (_) {
      // An expired token surfaces as a 401 on refresh() and signs out there.
    }
  }

  /// Notifications and caches are conveniences: a failure there is logged
  /// and must never stop a break from being recorded.
  static Future<void> _quietly(Future<void> f) async {
    try {
      await f;
    } catch (e) {
      debugPrint('Savanna Grass: $e');
    }
  }
}
