import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savanna_grass/ai/gemma_runtime.dart';
import 'package:savanna_grass/api/savanna_api.dart';
import 'package:savanna_grass/app_state.dart';
import 'package:savanna_grass/domain/profile.dart';
import 'package:savanna_grass/storage.dart';
import 'package:savanna_grass/ui/profile_screen.dart';
import 'package:savanna_grass/ui/theme.dart';

import 'app_state_test.dart' show FakeServer, FakeReminders;

void main() {
  group('profile model', () {
    test('reads GET /me and labels the role', () {
      final p = Profile.fromJson({
        'id': 'u',
        'email': 'amani@example.com',
        'name': null,
        'timezone': 'Africa/Nairobi',
        'role': 'product_manager',
        'createdAt': '2026-08-01T09:00:00.000Z',
      });
      expect(p.displayName, 'amani@example.com', reason: 'no name is never guessed from the email');
      expect(p.initial, 'A');
      expect(p.roleLabel, 'Product manager');
    });

    test('offsets are formatted the way people read them', () {
      expect(formatOffset(Duration.zero), 'UTC');
      expect(formatOffset(const Duration(hours: 3)), 'UTC+3');
      expect(formatOffset(const Duration(hours: -4, minutes: -30)), 'UTC-4:30');
      expect(formatOffset(const Duration(hours: 5, minutes: 45)), 'UTC+5:45');
    });

    test('zone offsets follow the zone database, DST included', () {
      expect(zoneOffset('Africa/Nairobi', DateTime.utc(2026, 1, 1)), const Duration(hours: 3));
      expect(zoneOffset('Europe/London', DateTime.utc(2026, 1, 15)), Duration.zero);
      expect(zoneOffset('Europe/London', DateTime.utc(2026, 7, 15)), const Duration(hours: 1));
      expect(zoneOffset('UTC', DateTime.utc(2026)), Duration.zero, reason: "SavannaTime's default zone");
      expect(zoneOffset('Not/AZone', DateTime.utc(2026)), isNull);
    });

    test('a mismatch is reported only when the offsets differ right now', () {
      final now = DateTime.now();
      final phone = now.timeZoneOffset;
      // A zone guaranteed to differ from this machine's offset by an hour.
      final other = phone == const Duration(hours: 3) ? 'UTC' : 'Africa/Nairobi';
      expect(zoneMismatch(other, now)?.phone, phone);
      expect(zoneMismatch('Not/AZone', now), isNull);
    });
  });

  testWidgets('the profile page shows the account and edits the name', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await Storage().writeSession(const Session(token: 'tok', email: 'a@b.co'));
    final server = FakeServer();
    final state = AppState(
      api: SavannaApi(baseUrl: 'https://api.example.com', client: server.client),
      storage: Storage(),
      gemma: GemmaRuntime(),
      reminders: FakeReminders(),
    );

    await tester.runAsync(() => state.restore());
    await tester.pumpWidget(MaterialApp(
      theme: savannaTheme(Brightness.light),
      home: ProfileScreen(state: state),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(find.text('a@b.co'), findsWidgets);
    expect(find.textContaining('Member since Aug 2026 · Developer'), findsOneWidget);
    expect(find.text('Add your name'), findsOneWidget);

    await tester.tap(find.text('Add your name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Amani Mollel');
    await tester.tap(find.text('Save'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(server.user['name'], 'Amani Mollel');
    expect(find.text('Amani Mollel'), findsWidgets);
    expect(find.text('Add your name'), findsNothing);
    // The ticker started by restore() is cancelled by dispose().
    state.dispose();
  });
}
