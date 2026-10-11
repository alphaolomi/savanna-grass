import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'ai/gemma_runtime.dart';
import 'ai/quest_writer.dart';
import 'api/savanna_api.dart';
import 'domain/grass_debt.dart';
import 'domain/quest.dart';
import 'domain/screen_day.dart';
import 'storage.dart';

enum AuthStatus { unknown, signedOut, signedIn }

enum ModelStatus { checking, missing, downloading, ready, failed }

class AppState extends ChangeNotifier {
  AppState({
    required this.api,
    required this.storage,
    required this.gemma,
  }) {
    writer = LocalModelQuestWriter(
      generate: gemma.generate,
      isReady: () => modelStatus == ModelStatus.ready,
    );
  }

  final SavannaApi api;
  final Storage storage;
  final GemmaRuntime gemma;
  late final LocalModelQuestWriter writer;

  AuthStatus auth = AuthStatus.unknown;
  String? email;

  ModelStatus modelStatus = ModelStatus.checking;
  int downloadPercent = 0;
  String? modelError;

  ScreenDay day = ScreenDay.empty;
  int _serverOutdoorSeconds = 0;
  List<OutdoorBreak> pending = [];
  bool loading = false;
  String? loadError;
  DateTime? loadedAt;

  Setting setting = Setting.home;
  Quest? quest;
  bool writing = false;

  /// Outside time counts the moment the break ends, even before it syncs.
  int get outdoorSeconds =>
      _serverOutdoorSeconds +
      pending
          .where((b) => _isToday(b.start))
          .fold(0, (s, b) => s + b.end.difference(b.start).inSeconds);

  GrassDebt get debt => GrassDebt.compute(day, outdoorSeconds: outdoorSeconds);

  Future<void> boot() async {
    unawaited(_checkModel());
    final session = await storage.readSession();
    pending = await storage.readPending();
    if (session == null) {
      auth = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    api.token = session.token;
    email = session.email;
    auth = AuthStatus.signedIn;
    notifyListeners();
    await _refreshTokenIfNeeded();
    await refresh();
  }

  Future<void> signIn(String email, String password) async {
    final session = await api.login(email.trim(), password);
    api.token = session.token;
    await storage.writeSession(session);
    this.email = session.email;
    auth = AuthStatus.signedIn;
    notifyListeners();
    await refresh();
  }

  Future<void> signOut() async {
    try {
      await api.logout();
    } catch (_) {
      // Signing out locally must work offline; the token expires on its own.
    }
    api.token = null;
    await storage.clear();
    auth = AuthStatus.signedOut;
    email = null;
    day = ScreenDay.empty;
    _serverOutdoorSeconds = 0;
    pending = [];
    quest = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      await _flushPending();
      final now = DateTime.now();
      final results = await Future.wait([
        api.today(now),
        api.outdoorSecondsToday(now),
      ]);
      day = results[0] as ScreenDay;
      _serverOutdoorSeconds = results[1] as int;
      loadedAt = now;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await signOut();
        return;
      }
      loadError = e.message;
    } catch (e) {
      loadError = 'Offline — showing the last numbers we had.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

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
        now: DateTime.now(),
        setting: setting,
      ));
    } finally {
      writing = false;
      notifyListeners();
    }
  }

  /// Records a finished break: queued locally first, then sent. If the send
  /// fails the break stays queued and is retried on the next refresh — the
  /// client-generated id makes the retry land once.
  Future<bool> finishBreak({
    required String title,
    required DateTime start,
    required DateTime end,
    String? note,
  }) async {
    final b = OutdoorBreak(
      id: const Uuid().v4(),
      title: title,
      start: start,
      end: end,
      note: note,
    );
    pending = [...pending, b];
    await storage.writePending(pending);
    quest = null;
    notifyListeners();
    final synced = await _flushPending();
    if (synced) unawaited(refresh());
    return synced;
  }

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

  /// Returns true when the queue is empty afterwards.
  Future<bool> _flushPending() async {
    if (pending.isEmpty) return true;
    final remaining = <OutdoorBreak>[];
    for (final b in pending) {
      try {
        await api.logOutdoorBreak(b);
      } catch (_) {
        remaining.add(b);
      }
    }
    pending = remaining;
    await storage.writePending(pending);
    notifyListeners();
    return remaining.isEmpty;
  }

  /// SavannaTime tokens live 7 days; renew inside the last day so an app that
  /// is opened daily never gets signed out.
  Future<void> _refreshTokenIfNeeded() async {
    final token = api.token;
    if (token == null) return;
    final left = secondsUntilExpiry(token, DateTime.now());
    if (left == null || left > 24 * 3600) return;
    try {
      final fresh = await api.refresh();
      api.token = fresh;
      await storage.writeSession(Session(token: fresh, email: email ?? ''));
    } catch (_) {
      // An expired token surfaces as a 401 on refresh() and signs out there.
    }
  }

  static bool _isToday(DateTime t) {
    final now = DateTime.now();
    final l = t.toLocal();
    return l.year == now.year && l.month == now.month && l.day == now.day;
  }
}
