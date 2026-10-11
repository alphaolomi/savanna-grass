import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:savanna_grass/api/savanna_api.dart';
import 'package:savanna_grass/storage.dart';

void main() {
  test('login hits /api/v1/auth/login and returns the session', () async {
    late http.Request seen;
    final api = SavannaApi(
      baseUrl: 'https://api.example.com',
      client: MockClient((req) async {
        seen = req;
        return http.Response(
          jsonEncode({
            'token': 'tok',
            'user': {'id': 'u', 'email': 'a@b.co', 'createdAt': '2026-01-01T00:00:00Z'},
          }),
          200,
        );
      }),
    );
    final s = await api.login('a@b.co', 'pw');
    expect(seen.url.toString(), 'https://api.example.com/api/v1/auth/login');
    expect(seen.headers['Authorization'], isNull);
    expect(s.token, 'tok');
  });

  test('errors surface the server message and code', () async {
    final api = SavannaApi(
      baseUrl: 'https://api.example.com/',
      client: MockClient((_) async => http.Response(
            jsonEncode({'message': 'Too many attempts', 'code': 'RATE_LIMITED'}),
            429,
          )),
    );
    expect(
      () => api.login('a@b.co', 'pw'),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', 'Too many attempts')
          .having((e) => e.code, 'code', 'RATE_LIMITED')),
    );
  });

  test('today asks for the local date range with the bearer token', () async {
    late Uri url;
    late String? auth;
    final api = SavannaApi(
      baseUrl: 'https://api.example.com',
      client: MockClient((req) async {
        url = req.url;
        auth = req.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'summary': {'totalSeconds': 60, 'pulse': 50, 'secondsByLevel': {}, 'topApps': []},
          }),
          200,
        );
      }),
    )..token = 'tok';
    final d = await api.today(DateTime(2026, 3, 7, 23, 59));
    expect(url.path, '/api/v1/stats/summary');
    expect(url.queryParameters, {'from': '2026-03-07', 'to': '2026-03-07'});
    expect(auth, 'Bearer tok');
    expect(d.totalSeconds, 60);
  });

  test('outdoor breaks: only finished entries this app wrote, title and note split', () async {
    final api = SavannaApi(
      baseUrl: 'https://api.example.com',
      // Bytes with no charset, as a server may send them: the client must
      // still read the 🌿 marker as UTF-8.
      client: MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode({
              'entries': [
                {'description': '$outdoorMarker · Sky — two hawks', 'startTime': '2026-10-11T10:00:00Z', 'endTime': '2026-10-11T10:12:00Z'},
                {'description': '$outdoorMarker · Running', 'startTime': '2026-10-11T11:00:00Z', 'endTime': null},
                {'description': 'Client call', 'startTime': '2026-10-11T12:00:00Z', 'endTime': '2026-10-11T13:00:00Z'},
                {'description': null, 'startTime': '2026-10-11T14:00:00Z', 'endTime': '2026-10-11T14:10:00Z'},
              ],
            })),
            200,
            headers: {'content-type': 'application/json'},
          )),
    );
    final breaks = await api.outdoorBreaks(DateTime(2026, 10, 5), DateTime(2026, 10, 11));
    expect(breaks, hasLength(1));
    expect(breaks.single.seconds, 12 * 60);
    expect(breaks.single.title, 'Sky');
    expect(breaks.single.note, 'two hawks');
  });

  test('a break is posted as a time entry with its client id', () async {
    late Map<String, dynamic> body;
    final api = SavannaApi(
      baseUrl: 'https://api.example.com',
      client: MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'entry': {}}), 200);
      }),
    );
    await api.logOutdoorBreak(OutdoorBreak(
      id: '11111111-1111-4111-8111-111111111111',
      title: 'Sky Watch',
      start: DateTime.utc(2026, 10, 11, 10),
      end: DateTime.utc(2026, 10, 11, 10, 15),
      note: '  two hawks  ',
    ));
    expect(body, {
      'id': '11111111-1111-4111-8111-111111111111',
      'description': '$outdoorMarker · Sky Watch — two hawks',
      'startTime': '2026-10-11T10:00:00.000Z',
      'endTime': '2026-10-11T10:15:00.000Z',
    });
  });

  test('a pending break round-trips through storage JSON', () {
    final b = OutdoorBreak(
      id: 'x',
      title: 'T',
      start: DateTime.utc(2026, 1, 1, 9),
      end: DateTime.utc(2026, 1, 1, 9, 20),
    );
    final back = OutdoorBreak.fromJson(jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>);
    expect(back.description, b.description);
    expect(back.end.difference(back.start), const Duration(minutes: 20));
  });

  test('secondsUntilExpiry reads exp without verifying', () {
    String part(Map<String, dynamic> m) =>
        base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    final now = DateTime.utc(2026, 10, 11);
    final exp = now.millisecondsSinceEpoch ~/ 1000 + 3600;
    final jwt = '${part({'alg': 'HS256'})}.${part({'exp': exp})}.sig';
    expect(secondsUntilExpiry(jwt, now), 3600);
    expect(secondsUntilExpiry('garbage', now), isNull);
  });
}
