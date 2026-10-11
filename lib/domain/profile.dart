import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The SavannaTime account behind the session, as `GET /me` returns it.
class Profile {
  const Profile({
    required this.id,
    required this.email,
    required this.name,
    required this.timezone,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String email;

  /// Null until the person sets one. Never guessed from the email: greeting
  /// someone by a made-up name is worse than a neutral greeting.
  final String? name;

  /// IANA zone SavannaTime buckets this account's days in.
  final String timezone;

  /// Role profile key, e.g. `developer`; null if none was picked.
  final String? role;
  final DateTime createdAt;

  /// The name, or the email when there is none — for a heading, not a greeting.
  String get displayName => name ?? email;

  String get initial => displayName.isEmpty ? '?' : displayName.substring(0, 1).toUpperCase();

  /// `developer` → `Developer`, `product_manager` → `Product manager`.
  String? get roleLabel {
    final r = role;
    if (r == null || r.isEmpty) return null;
    final words = r.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    return words.substring(0, 1).toUpperCase() + words.substring(1);
  }

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        email: j['email'] as String,
        name: j['name'] as String?,
        timezone: j['timezone'] as String? ?? 'UTC',
        role: j['role'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      );
}

bool _tzReady = false;

/// The UTC offset [iana] has at [at], or null for a zone this build does not
/// know. Loads the zone database on first use (~100 KB, in memory only).
Duration? zoneOffset(String iana, DateTime at) {
  if (!_tzReady) {
    tzdata.initializeTimeZones();
    _tzReady = true;
  }
  try {
    // SavannaTime's default zone is the bare name `UTC`, which the zone
    // database does not list as a location.
    final loc = iana == 'UTC' ? tz.UTC : tz.getLocation(iana);
    return loc.timeZone(at.millisecondsSinceEpoch).offset;
  } on tz.LocationNotFoundException {
    return null;
  }
}

/// `UTC+3`, `UTC-4:30`, `UTC`.
String formatOffset(Duration d) {
  if (d == Duration.zero) return 'UTC';
  final sign = d.isNegative ? '-' : '+';
  final m = d.inMinutes.abs();
  final h = m ~/ 60;
  final rest = m % 60;
  return 'UTC$sign$h${rest == 0 ? '' : ':${rest.toString().padLeft(2, '0')}'}';
}

/// When the account's zone and the phone's disagree right now, the phone's
/// "today" and SavannaTime's start at different hours — screen time and time
/// outside near midnight land on different days. Returns both offsets then,
/// null when they agree (or the zone is unknown).
({Duration account, Duration phone})? zoneMismatch(String accountZone, DateTime now) {
  final account = zoneOffset(accountZone, now);
  final phone = now.timeZoneOffset;
  if (account == null || account == phone) return null;
  return (account: account, phone: phone);
}
