import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:savanna_grass/ai/gemma_runtime.dart';
import 'package:savanna_grass/api/savanna_api.dart';
import 'package:savanna_grass/app_state.dart';
import 'package:savanna_grass/domain/active_break.dart';
import 'package:savanna_grass/domain/quest.dart';
import 'package:savanna_grass/domain/reminder_plan.dart';
import 'package:savanna_grass/reminders.dart';
import 'package:savanna_grass/storage.dart';

/// SavannaTime, as far as this app sees it: screen time per local date, and
/// the time entries it has been sent.
class FakeServer {
  final screenSeconds = <String, int>{};
  final entries = <String, Map<String, dynamic>>{};
  final summaryDates = <String>[];
  bool offline = false;
  final user = <String, dynamic>{
    'id': '00000000-0000-0000-0000-000000000001',
    'email': 'a@b.co',
    'name': null,
    'timezone': 'Africa/Nairobi',
    'role': 'developer',
    'createdAt': '2026-08-01T09:00:00.000Z',
    'lastLoginAt': null,
  };

  /// When set, every request waits for it — a slow network.
  Completer<void>? gate;

  late final http.Client client = MockClient((req) async {
    final g = gate;
    if (g != null) await g.future;
    if (offline) throw http.ClientException('offline');
    final path = req.url.path;
    if (path.endsWith('stats/summary')) {
      final d = req.url.queryParameters['from']!;
      summaryDates.add(d);
      return _json({
        'summary': {'totalSeconds': screenSeconds[d] ?? 0, 'secondsByLevel': {}, 'pulse': null, 'topApps': []},
      });
    }
    if (path.endsWith('time-entries') && req.method == 'POST') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      entries[body['id'] as String] = body; // idempotent on the client id, like the server
      return _json(body, 201);
    }
    if (path.endsWith('time-entries')) {
      return _json({'entries': entries.values.toList()});
    }
    if (path.endsWith('auth/logout')) return _json({});
    if (path.endsWith('/me/name')) {
      final name = ((jsonDecode(req.body) as Map)['name'] as String).trim();
      user['name'] = name.isEmpty ? null : name;
      return _json({'user': user});
    }
    if (path.endsWith('/me')) return _json({'user': user});
    return http.Response('not found', 404);
  });

  // Bytes, not a String: http.Response encodes a String body as Latin-1 when
  // no charset is given, and the 🌿 marker is not Latin-1.
  static http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}

class FakeReminders extends NoReminders {
  final shown = <ActiveBreak>[];
  int cleared = 0;
  List<PlannedReminder> daily = const [];

  @override
  bool get supported => true;
  @override
  Future<void> showBreak(ActiveBreak b, {required bool alarm, required DateTime now}) async => shown.add(b);
  @override
  Future<void> clearBreak() async => cleared++;
  @override
  Future<void> setDaily(List<PlannedReminder> plan) async => daily = plan;
}

const quest = Quest(title: 'Sky Survey', minutes: 10, steps: 'Look up.', why: 'x', source: QuestSource.template);

/// Lets queued microtasks and unawaited futures run to completion.
Future<void> settle() async {
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeServer server;
  late DateTime clock;
  late FakeReminders reminders;

  AppState newApp() {
    final s = AppState(
      api: SavannaApi(baseUrl: 'https://api.example.com', client: server.client),
      storage: Storage(),
      gemma: GemmaRuntime(),
      reminders: reminders,
      clock: () => clock,
    );
    addTearDown(s.dispose);
    return s;
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await Storage().writeSession(const Session(token: 'tok', email: 'a@b.co'));
    server = FakeServer()
      ..screenSeconds['2026-10-11'] = 3 * 3600
      ..screenSeconds['2026-10-12'] = 600;
    reminders = FakeReminders();
    clock = DateTime(2026, 10, 11, 23, 58);
  });

  group('midnight', () {
    test('the new day drops yesterday\'s screen time and reads today\'s', () async {
      final app = newApp();
      await app.restore();
      expect(app.day.totalSeconds, 3 * 3600);
      expect(app.debt.owedMinutes, 30);

      clock = DateTime(2026, 10, 12, 0, 1);
      expect(app.checkDay(), isTrue);
      expect(app.day.totalSeconds, 0, reason: 'nothing owed from yesterday, even before the server answers');
      await settle();
      expect(server.summaryDates.last, '2026-10-12');
      expect(app.day.totalSeconds, 600);
      expect(app.checkDay(), isFalse);
    });

    test('a refresh in flight at midnight does not land as the new day', () async {
      final app = newApp();
      await app.restore();

      server.gate = Completer();
      final slow = app.refresh();
      await settle();
      clock = DateTime(2026, 10, 12, 0, 1);
      app.checkDay();
      server.gate!.complete();
      server.gate = null;
      await slow;
      await settle();

      expect(app.day.totalSeconds, 600);
      expect(server.summaryDates.last, '2026-10-12');
    });

    test('a break across midnight pays both days', () async {
      final app = newApp();
      await app.restore();
      clock = DateTime(2026, 10, 11, 23, 50);
      await app.startBreak(quest);
      clock = DateTime(2026, 10, 12, 0, 10);
      await app.finishBreak();
      app.checkDay();
      await settle();
      expect(app.outdoorSeconds, 600);
      expect(app.week.minutes.sublist(5), [10, 10]);
    });
  });

  group('background and restarts', () {
    test('a running break, and its note, outlive the app being killed', () async {
      final first = newApp();
      await first.restore();
      await first.startBreak(quest);
      first.updateBreakNote('two hawks');
      first.onBackgrounded();
      await settle();

      clock = clock.add(const Duration(minutes: 40));
      final second = newApp();
      await second.restore();
      expect(second.activeBreak?.id, first.activeBreak?.id);
      expect(second.activeBreak?.note, 'two hawks');
      expect(reminders.shown, hasLength(2), reason: 'the timer notification is put back after a reboot');

      expect(await second.finishBreak(), BreakOutcome.synced);
      expect(server.entries.values.single['description'], contains('two hawks'));
      expect(second.activeBreak, isNull);
      expect(reminders.cleared, greaterThan(0));
      await settle();
    });

    test('killed between queueing a break and clearing it: logged once, not resumed', () async {
      final b = ActiveBreak(id: 'b-1', title: 'x', steps: '', minutes: 10, start: clock);
      await Storage().writeActiveBreak(b);
      await Storage().writePending([
        OutdoorBreak(id: 'b-1', title: 'x', start: clock, end: clock.add(const Duration(minutes: 5))),
      ]);
      final app = newApp();
      await app.restore();
      expect(app.activeBreak, isNull);
      expect(server.entries.keys, ['b-1']);
    });

    test('an offline launch shows the last numbers from today, not yesterday', () async {
      await newApp().restore();
      await settle();

      server.offline = true;
      final offline = newApp();
      await offline.restore();
      expect(offline.day.totalSeconds, 3 * 3600);
      expect(offline.loadError, contains('showing numbers from 23:58'));

      clock = DateTime(2026, 10, 12, 8);
      final tomorrow = newApp();
      await tomorrow.restore();
      expect(tomorrow.day.totalSeconds, 0);
      expect(tomorrow.loadedAt, isNull);
    });

    test('coming back after a while re-reads the numbers', () async {
      final app = newApp();
      await app.restore();
      final before = server.summaryDates.length;
      server.screenSeconds['2026-10-11'] = 4 * 3600;
      clock = clock.add(const Duration(seconds: 90));
      app.onResumed();
      await settle();
      expect(server.summaryDates.length, before + 1);
      expect(app.day.totalSeconds, 4 * 3600);
    });
  });

  group('sync', () {
    test('a break finished while another flush runs is sent once and counted once', () async {
      final app = newApp();
      await app.restore();
      clock = DateTime(2026, 10, 11, 20);
      server.offline = true;
      await app.startBreak(quest);
      clock = clock.add(const Duration(minutes: 12));
      expect(await app.finishBreak(), BreakOutcome.queued);

      server.offline = false;
      await app.startBreak(quest);
      clock = clock.add(const Duration(minutes: 15));
      await Future.wait([app.refresh(), app.finishBreak()]);
      await settle();

      expect(server.entries, hasLength(2));
      expect(app.pending, isEmpty);
      expect(app.todayBreaks, hasLength(2));
      expect(app.outdoorSeconds, 27 * 60);
    });

    test('signing out mid-refresh never writes the old account\'s numbers back', () async {
      final app = newApp();
      await app.restore();
      server.gate = Completer();
      final slow = app.refresh();
      await settle();
      final out = app.signOut();
      server.gate!.complete();
      server.gate = null;
      await Future.wait([slow, out]);
      await settle();
      expect(app.auth, AuthStatus.signedOut);
      expect(app.day.totalSeconds, 0);
      expect(reminders.daily, isEmpty);
    });

    test('today\'s nudge is booked from the latest debt', () async {
      final app = newApp();
      clock = DateTime(2026, 10, 11, 9);
      await app.restore();
      await settle();
      expect(reminders.daily.first.at, DateTime(2026, 10, 11, 17, 30));
      expect(reminders.daily.first.title, contains('30 min'));
    });
  });

  group('profile', () {
    test('loads with the session and is forgotten on sign-out', () async {
      final app = newApp();
      await app.restore();
      await settle();
      expect(app.profile?.roleLabel, 'Developer');
      expect(app.profile?.name, isNull);

      await app.setName('  Amani Mollel ');
      expect(app.profile?.name, 'Amani Mollel');
      expect(server.user['name'], 'Amani Mollel');

      await app.signOut();
      expect(app.profile, isNull);
    });

    test("a profile answering after sign-out is not kept", () async {
      final app = newApp();
      await app.restore();
      await settle();
      app.profile = null;
      server.gate = Completer();
      final slow = app.loadProfile();
      await settle();
      final out = app.signOut();
      server.gate!.complete();
      server.gate = null;
      await Future.wait([slow, out]);
      expect(app.profile, isNull);
    });

    test('offline, the page says so instead of failing', () async {
      final app = newApp();
      server.offline = true;
      await app.restore();
      await settle();
      expect(app.profile, isNull);
      expect(app.profileError, contains('offline'));
    });
  });
}
