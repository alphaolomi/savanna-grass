import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api/savanna_api.dart';
import 'domain/active_break.dart';
import 'domain/outdoor_log.dart';
import 'domain/reminder_plan.dart';
import 'domain/screen_day.dart';

/// Keychain / Keystore-backed storage: the session token, outdoor breaks that
/// have not reached the server yet, the break in progress, and the last
/// numbers the server gave — everything the app needs to come back exactly
/// where it was after Android kills it in a pocket.
class Storage {
  Storage([FlutterSecureStorage? storage])
      : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  static const _token = 'token';
  static const _email = 'email';
  static const _pending = 'pending_breaks';
  static const _theme = 'theme_mode';
  static const _active = 'active_break';
  static const _snapshot = 'snapshot';
  static const _reminders = 'reminders';

  Future<Session?> readSession() async {
    final token = await _s.read(key: _token);
    final email = await _s.read(key: _email);
    if (token == null || email == null) return null;
    return Session(token: token, email: email);
  }

  Future<void> writeSession(Session s) async {
    await _s.write(key: _token, value: s.token);
    await _s.write(key: _email, value: s.email);
  }

  /// Signs out: the session, unsynced breaks, the break in progress and the
  /// cached numbers go — they belong to the account. The theme and reminder
  /// choices belong to the phone and stay.
  Future<void> clearSession() async {
    await _s.delete(key: _token);
    await _s.delete(key: _email);
    await _s.delete(key: _pending);
    await _s.delete(key: _active);
    await _s.delete(key: _snapshot);
  }

  Future<ActiveBreak?> readActiveBreak() async {
    final j = await _readJson(_active);
    return j == null ? null : ActiveBreak.fromJson(j);
  }

  Future<void> writeActiveBreak(ActiveBreak b) => _s.write(key: _active, value: jsonEncode(b.toJson()));

  Future<void> clearActiveBreak() => _s.delete(key: _active);

  Future<Snapshot?> readSnapshot() async {
    final j = await _readJson(_snapshot);
    return j == null ? null : Snapshot.fromJson(j);
  }

  Future<void> writeSnapshot(Snapshot s) => _s.write(key: _snapshot, value: jsonEncode(s.toJson()));

  Future<ReminderSettings> readReminderSettings() async {
    final j = await _readJson(_reminders);
    return j == null ? const ReminderSettings() : ReminderSettings.fromJson(j);
  }

  Future<void> writeReminderSettings(ReminderSettings r) =>
      _s.write(key: _reminders, value: jsonEncode(r.toJson()));

  /// A value written by an older build in a shape this one cannot read is
  /// treated as absent rather than crashing the launch.
  Future<Map<String, dynamic>?> _readJson(String key) async {
    final raw = await _s.read(key: key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<ThemeMode> readThemeMode() async {
    final v = await _s.read(key: _theme);
    return ThemeMode.values.firstWhere((m) => m.name == v, orElse: () => ThemeMode.system);
  }

  Future<void> writeThemeMode(ThemeMode m) => _s.write(key: _theme, value: m.name);

  Future<List<OutdoorBreak>> readPending() async {
    final raw = await _s.read(key: _pending);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map(OutdoorBreak.fromJson)
        .toList();
  }

  Future<void> writePending(List<OutdoorBreak> breaks) => _s.write(
        key: _pending,
        value: jsonEncode(breaks.map((b) => b.toJson()).toList()),
      );
}

/// The last numbers the server gave, kept so a launch with no signal shows
/// them instead of zeros. [day] only counts for the local date it was read on.
class Snapshot {
  const Snapshot({
    required this.date,
    required this.day,
    required this.breaks,
    required this.loadedAt,
    this.weekTotals,
  });

  /// `yyyy-mm-dd` of the local day [day] belongs to.
  final String date;
  final ScreenDay day;
  final List<LoggedBreak> breaks;
  final DateTime loadedAt;

  /// The week's per-day totals; absent in caches from before 1.2.
  final List<DayTotals>? weekTotals;

  Map<String, dynamic> toJson() => {
        'date': date,
        'day': day.toSummaryJson(),
        'breaks': [for (final b in breaks) b.toJson()],
        'loadedAt': loadedAt.toUtc().toIso8601String(),
        if (weekTotals != null) 'weekTotals': [for (final d in weekTotals!) d.toJson()],
      };

  factory Snapshot.fromJson(Map<String, dynamic> j) => Snapshot(
        date: j['date'] as String,
        day: ScreenDay.fromSummaryJson(j['day'] as Map<String, dynamic>),
        breaks: (j['breaks'] as List).cast<Map<String, dynamic>>().map(LoggedBreak.fromJson).toList(),
        loadedAt: DateTime.parse(j['loadedAt'] as String).toLocal(),
        weekTotals: (j['weekTotals'] as List?)?.cast<Map<String, dynamic>>().map(DayTotals.fromJson).toList(),
      );
}

/// Seconds until a JWT expires, read from its `exp` claim without verifying —
/// only used to decide when to ask the server for a fresh one.
int? secondsUntilExpiry(String jwt, DateTime now) {
  final parts = jwt.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    ) as Map<String, dynamic>;
    final exp = payload['exp'] as num?;
    if (exp == null) return null;
    return exp.toInt() - now.millisecondsSinceEpoch ~/ 1000;
  } on FormatException {
    return null;
  }
}
