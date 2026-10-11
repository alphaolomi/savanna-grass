import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/local_day.dart';
import '../domain/outdoor_log.dart';
import '../domain/profile.dart';
import '../domain/screen_day.dart';

/// Every time entry this app writes starts with this, so outdoor time is
/// recognisable in SavannaTime's web dashboard and countable here.
const outdoorMarker = '🌿 Touch grass';

/// Splits `🌿 Touch grass · <title> — <note>` back into title and note.
(String, String?) parseOutdoorDescription(String desc) {
  var rest = desc.substring(outdoorMarker.length).trim();
  if (rest.startsWith('·')) rest = rest.substring(1).trim();
  final cut = rest.indexOf(' — ');
  if (cut < 0) return (rest.isEmpty ? 'Outside' : rest, null);
  return (rest.substring(0, cut).trim(), rest.substring(cut + 3).trim());
}

class ApiException implements Exception {
  const ApiException(this.status, this.message, [this.code]);

  final int status;
  final String message;
  final String? code;

  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

class Session {
  const Session({required this.token, required this.email});

  final String token;
  final String email;
}

/// A finished outdoor break, ready to become a SavannaTime time entry.
///
/// `id` is client-generated, exactly like SavannaTime's own activity logs:
/// re-posting the same id returns the stored entry, so a retry after a dropped
/// connection can never double-count time outside.
class OutdoorBreak {
  const OutdoorBreak({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.note,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? note;

  String get description {
    final base = '$outdoorMarker · $title';
    final n = note?.trim();
    final full = (n == null || n.isEmpty) ? base : '$base — $n';
    return full.length > 500 ? full.substring(0, 500) : full;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        if (note != null) 'note': note,
      };

  factory OutdoorBreak.fromJson(Map<String, dynamic> j) => OutdoorBreak(
        id: j['id'] as String,
        title: j['title'] as String,
        start: DateTime.parse(j['start'] as String),
        end: DateTime.parse(j['end'] as String),
        note: j['note'] as String?,
      );
}

/// Thin client for the SavannaTime API (`/api/v1`).
class SavannaApi {
  SavannaApi({required String baseUrl, http.Client? client})
      : _base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/')
            .resolve('api/v1/'),
        _http = client ?? http.Client();

  final Uri _base;
  final http.Client _http;
  String? token;

  Future<Session> login(String email, String password) async {
    final json = await _send('POST', 'auth/login',
        body: {'email': email, 'password': password}, auth: false);
    final user = json['user'] as Map<String, dynamic>;
    return Session(token: json['token'] as String, email: user['email'] as String);
  }

  /// Renews a still-valid token in place (SavannaTime `POST /auth/refresh`).
  Future<String> refresh() async {
    final json = await _send('POST', 'auth/refresh');
    return json['token'] as String;
  }

  Future<void> logout() => _send('POST', 'auth/logout');

  /// The account behind the token (SavannaTime `GET /me`).
  Future<Profile> me() async {
    final json = await _send('GET', 'me');
    return Profile.fromJson(json['user'] as Map<String, dynamic>);
  }

  /// Sets the display name; an empty or blank name clears it.
  Future<Profile> setName(String name) async {
    final json = await _send('PUT', 'me/name', body: {'name': name});
    return Profile.fromJson(json['user'] as Map<String, dynamic>);
  }

  /// One local day's screen time. `from`/`to` are *local* calendar dates; the
  /// server buckets them in the user's SavannaTime timezone.
  Future<ScreenDay> today(DateTime day) async {
    final d = _date(day);
    final json = await _send('GET', 'stats/summary?from=$d&to=$d');
    return ScreenDay.fromSummaryJson(json['summary'] as Map<String, dynamic>);
  }

  /// Finished outdoor breaks this app logged between two local dates,
  /// inclusive. Other time entries in SavannaTime are ignored.
  Future<List<LoggedBreak>> outdoorBreaks(DateTime from, DateTime to) async {
    final json = await _send('GET', 'time-entries?from=${_date(from)}&to=${_date(to)}');
    final breaks = <LoggedBreak>[];
    for (final e in (json['entries'] as List).cast<Map<String, dynamic>>()) {
      final desc = e['description'] as String? ?? '';
      final end = e['endTime'] as String?;
      if (!desc.startsWith(outdoorMarker) || end == null) continue;
      final (title, note) = parseOutdoorDescription(desc);
      breaks.add(LoggedBreak(
        start: DateTime.parse(e['startTime'] as String).toLocal(),
        end: DateTime.parse(end).toLocal(),
        title: title,
        note: note,
      ));
    }
    return breaks;
  }

  Future<void> logOutdoorBreak(OutdoorBreak b) => _send('POST', 'time-entries',
      body: {
        'id': b.id,
        'description': b.description,
        'startTime': b.start.toUtc().toIso8601String(),
        'endTime': b.end.toUtc().toIso8601String(),
      });

  static String _date(DateTime d) => dateKey(d);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final req = http.Request(method, _base.resolve(path))
      ..headers['Accept'] = 'application/json';
    if (auth && token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final res = await http.Response.fromStream(await _http.send(req));
    Map<String, dynamic> json = const {};
    if (res.bodyBytes.isNotEmpty) {
      try {
        // Always UTF-8: `res.body` falls back to Latin-1 when the server omits
        // a charset, which would mangle the 🌿 marker on the way back in.
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) json = decoded;
      } on FormatException {
        // Non-JSON error page from a proxy; fall through to the status check.
      }
    }
    if (res.statusCode >= 400) {
      throw ApiException(
        res.statusCode,
        json['message'] as String? ?? 'Request failed (${res.statusCode})',
        json['code'] as String?,
      );
    }
    return json;
  }
}
