import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savanna_grass/ai/gemma_runtime.dart';
import 'package:savanna_grass/api/savanna_api.dart';
import 'package:savanna_grass/app_state.dart';
import 'package:savanna_grass/storage.dart';
import 'package:savanna_grass/ui/day_screen.dart';
import 'package:savanna_grass/ui/theme.dart';
import 'package:savanna_grass/ui/week_screen.dart';

import 'app_state_test.dart' show FakeServer, FakeReminders;

/// Sunday 12 October 2026, 15:00: three hours on screens (one distracting),
/// one 20-minute break at noon.
Future<AppState> seeded(WidgetTester tester) async {
  FlutterSecureStorage.setMockInitialValues({});
  await Storage().writeSession(const Session(token: 'tok', email: 'a@b.co'));
  final start = DateTime(2026, 10, 12, 12);
  final server = FakeServer()
    ..screenSeconds['2026-10-12'] = 3 * 3600
    ..distractingSeconds['2026-10-12'] = 3600
    ..topApps.add({'appName': 'Code', 'totalSeconds': 7200, 'productivity': 2, 'category': 'development', 'sessions': 9})
    ..entries['b-1'] = {
      'id': 'b-1',
      'description': '🌿 Touch grass · Sky Survey — two hawks',
      'startTime': start.toUtc().toIso8601String(),
      'endTime': start.add(const Duration(minutes: 20)).toUtc().toIso8601String(),
    };
  final state = AppState(
    api: SavannaApi(baseUrl: 'https://api.example.com', client: server.client),
    storage: Storage(),
    gemma: GemmaRuntime(),
    reminders: FakeReminders(),
    clock: () => DateTime(2026, 10, 12, 15),
  );
  await tester.runAsync(state.restore);
  return state;
}

Future<void> show(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(MaterialApp(theme: savannaTheme(Brightness.light), home: page));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
}

void main() {
  testWidgets('the day page works the debt through, then opens a break', (tester) async {
    final state = await seeded(tester);
    await show(tester, DayScreen(state: state, day: DateTime(2026, 10, 12)));

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('3h 00m on screens × 10 min/h'), findsOneWidget);
    expect(find.text('+5 min'), findsOneWidget);
    expect(find.text('35 min'), findsOneWidget, reason: 'owed');
    expect(find.text('−20 min'), findsOneWidget, reason: 'paid outside');
    expect(find.text('15 min to go'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Code'), 300);
    expect(find.textContaining('development · 9 sessions'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Sky Survey'), 300);
    await tester.tap(find.text('Sky Survey'));
    await tester.pumpAndSettle();
    expect(find.text('“two hawks”'), findsOneWidget);
    expect(find.text('20 min of the 35 min owed'), findsOneWidget);
    expect(find.text('In SavannaTime'), findsOneWidget);
    state.dispose();
  });

  testWidgets('the week page counts settled days and opens one', (tester) async {
    final state = await seeded(tester);
    await show(tester, WeekScreen(state: state));

    expect(find.text('6 of 7 days paid'), findsOneWidget, reason: 'six days owed nothing');
    expect(find.text('15 min to go'), findsOneWidget);

    await tester.tap(find.textContaining('Today · '));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text('3h 00m on screens × 10 min/h'), findsOneWidget);
    state.dispose();
  });
}
