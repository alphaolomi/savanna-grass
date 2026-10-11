import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api/savanna_api.dart';

/// Keychain / Keystore-backed storage for the session token and for outdoor
/// breaks that have not reached the server yet.
class Storage {
  Storage([FlutterSecureStorage? storage])
      : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  static const _token = 'token';
  static const _email = 'email';
  static const _pending = 'pending_breaks';
  static const _theme = 'theme_mode';

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

  /// Signs out: the session and any unsynced breaks go; the theme stays.
  Future<void> clearSession() async {
    await _s.delete(key: _token);
    await _s.delete(key: _email);
    await _s.delete(key: _pending);
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
