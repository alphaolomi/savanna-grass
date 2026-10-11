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

  /// Of [screenSeconds], how much was very distracting (-2), per date.
  final distractingSeconds = <String, int>{};
  final timelineDates = <String>[];
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
        'summary': {
          'totalSeconds': screenSeconds[d] ?? 0,
          'secondsByLevel': {'-2': distractingSeconds[d] ?? 0},
          'pulse': null,
          'topApps': [],
        },
      });
    }
    if (path.endsWith('stats/daily')) {
      // Like the server: only days with something tracked get a row.
      final from = DateTime.parse(req.url.queryParameters['from']!);
      final to = DateTime.parse(req.url.queryParameters['to']!);
      return _json({
        'days': [
          for (var d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1))
            if ((screenSeconds[_key(d)] ?? 0) > 0)
              {
                'date': _key(d),
                'total': screenSeconds[_key(d)],
                'secondsByLevel': {'-2': distractingSeconds[_key(d)] ?? 0},
              },
        ],
      });
    }
    if (path.endsWith('stats/timeline')) {
      final d = req.url.queryParameters['from']!;
      timelineDates.add(d);
      // All of the day's screen time lands in 09:00.
      return _json({
        'hours': [
          for (var h = 0; h < 24; h++)
            {'hour': h, 'totalSeconds': h == 9 ? screenSeconds[d] ?? 0 : 0, 'secondsByLevel': {}},
        ],
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

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  group('history', () {
    test('the week arrives with every refresh, quiet days included', () async {
      server
        ..screenSeconds['2026-10-09'] = 2 * 3600
        ..distractingSeconds['2026-10-09'] = 3600;
      final app = newApp();
      await app.restore();
      final week = app.weekDays;
      expect(week.map((r) => r.day.day), [5, 6, 7, 8, 9, 10, 11]);
      final thu = week[4];
      expect((thu.screenKnown, thu.screenSeconds, thu.debt.owedMinutes), (true, 7200, 25));
      expect((week[3].screenKnown, week[3].screenSeconds), (true, 0));
      expect(week.last.screenSeconds, 3 * 3600, reason: 'today comes from the live summary');
    });

    test('the week is kept for an offline launch', () async {
      server.screenSeconds['2026-10-09'] = 3600;
      await newApp().restore();
      await settle();
      server.offline = true;
      final offline = newApp();
      await offline.restore();
      expect(offline.weekDays[4].screenSeconds, 3600);
    });

    test('a past day is read once; pull-to-refresh reads it again', () async {
      server.screenSeconds['2026-10-09'] = 3600;
      final app = newApp();
      await app.restore();
      final thu = DateTime(2026, 10, 9);

      await app.loadDetail(thu);
      expect(app.detailFor(thu).data?.hours[9].totalSeconds, 3600);
      await app.loadDetail(thu);
      expect(server.timelineDates.where((d) => d == '2026-10-09'), hasLength(1));

      server.screenSeconds['2026-10-09'] = 4000;
      await app.loadDetail(thu, force: true);
      expect(server.timelineDates.where((d) => d == '2026-10-09'), hasLength(2));
      expect(app.recordFor(thu).screenSeconds, 4000, reason: 'the fresher detail beats the daily row');
    });

    test("today's detail goes stale, and its fresh read updates the hero", () async {
      final app = newApp();
      await app.restore();
      final today = DateTime(2026, 10, 11);
      await app.loadDetail(today);
      server.screenSeconds['2026-10-11'] = 4 * 3600;
      await app.loadDetail(today);
      expect(app.day.totalSeconds, 3 * 3600, reason: 'still fresh: not read again');

      clock = clock.add(const Duration(seconds: 61));
      await app.loadDetail(today);
      expect(app.detailFor(today).data?.screen.totalSeconds, 4 * 3600);
      expect(app.day.totalSeconds, 4 * 3600);
    });

    test('offline, a detail keeps what it had and says why', () async {
      final app = newApp();
      await app.restore();
      final thu = DateTime(2026, 10, 9);
      await app.loadDetail(thu);
      server.offline = true;
      await app.loadDetail(thu, force: true);
      final d = app.detailFor(thu);
      expect(d.hasData, isTrue);
      expect(d.error, contains('offline'));
    });

    test("midnight drops the finished day's partial detail", () async {
      final app = newApp();
      await app.restore();
      await app.loadDetail(DateTime(2026, 10, 11));
      clock = DateTime(2026, 10, 12, 0, 1);
      app.checkDay();
      expect(app.detailFor(DateTime(2026, 10, 11)).hasData, isFalse);
      await settle();
    });

    test('sign-out forgets the history, and a late detail is not kept', () async {
      final app = newApp();
      await app.restore();
      server.gate = Completer();
      final slow = app.loadDetail(DateTime(2026, 10, 9));
      await settle();
      final out = app.signOut();
      server.gate!.complete();
      server.gate = null;
      await Future.wait([slow, out]);
      expect(app.detailFor(DateTime(2026, 10, 9)).hasData, isFalse);
      expect(app.weekDays.every((r) => !r.screenKnown || r.day == app.today), isTrue);
    });

    test('a break can be found by id whether queued or synced', () async {
      final app = newApp();
      await app.restore();
      server.offline = true;
      await app.startBreak(quest);
      final id = app.activeBreak!.id;
      clock = clock.add(const Duration(minutes: 5));
      await app.finishBreak();
      expect(app.breakById(id)?.pending, isTrue);
      server.offline = false;
      await app.refresh();
      await settle();
      expect(app.breakById(id)?.pending, isFalse);
    });
  });
}
