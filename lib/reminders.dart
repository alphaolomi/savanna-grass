import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'domain/active_break.dart';
import 'domain/reminder_plan.dart';
import 'persona.dart';

/// Notifications the OS shows on the app's behalf, including while it is
/// closed: the running break timer, the quest-time alarm, and the daily nudge.
///
/// Everything here is best-effort. A refused permission or a platform error
/// must never stop a break from being logged, so [AppState] calls these
/// without letting a failure propagate.
abstract class Reminders {
  /// False where there is nothing to schedule with (the web build, tests).
  bool get supported;

  /// [onOpen] runs when a notification is tapped while the app is alive.
  Future<void> init({VoidCallback? onOpen});

  Future<bool> isPermitted();

  /// Asks for permission to notify (Android 13+, iOS). True when allowed.
  Future<bool> ensurePermission();

  /// Whether alarms can fire on the minute. Android 14 grants this only when
  /// the person allows "Alarms & reminders" for the app; without it the OS
  /// may hold a reminder back by a few minutes to save battery.
  Future<bool> canRingOnTime();

  /// Opens the system setting behind [canRingOnTime].
  Future<void> requestRingOnTime();

  /// Shows the running timer for [b] and, when [alarm] is on, books the
  /// quest-time alarm and a later check-in. Safe to call again: it replaces.
  Future<void> showBreak(ActiveBreak b, {required bool alarm, required DateTime now});

  Future<void> clearBreak();

  /// Replaces every booked daily nudge with [plan].
  Future<void> setDaily(List<PlannedReminder> plan);
}

/// Does nothing. Used on the web, where scheduled notifications do not exist.
class NoReminders implements Reminders {
  const NoReminders();

  @override
  bool get supported => false;
  @override
  Future<void> init({VoidCallback? onOpen}) async {}
  @override
  Future<bool> isPermitted() async => false;
  @override
  Future<bool> ensurePermission() async => false;
  @override
  Future<bool> canRingOnTime() async => false;
  @override
  Future<void> requestRingOnTime() async {}
  @override
  Future<void> showBreak(ActiveBreak b, {required bool alarm, required DateTime now}) async {}
  @override
  Future<void> clearBreak() async {}
  @override
  Future<void> setDaily(List<PlannedReminder> plan) async {}
}

/// Notification ids. Fixed, so re-booking replaces rather than stacks.
abstract final class NotificationIds {
  static const breakTimer = 1;
  static const questTime = 2;
  static const stillOutside = 3;

  /// Daily nudges take `dailyBase + slot`, slot 0 being today.
  static const dailyBase = 100;
}

/// How long after the quest time a still-running break gets a check-in.
const stillOutsideAfter = Duration(minutes: 45);

class DeviceReminders implements Reminders {
  final _plugin = FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  static const _darwin = DarwinNotificationDetails();

  static const _questTime = NotificationDetails(
    android: AndroidNotificationDetails(
      'quest_time',
      'Quest time',
      channelDescription: 'Rings when a break reaches its quest time',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: _darwin,
  );

  static const _daily = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_nudge',
      'Daily nudge',
      channelDescription: 'One reminder a day about your grass debt',
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: _darwin,
  );

  @override
  bool get supported => true;

  @override
  Future<void> init({VoidCallback? onOpen}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_grass'),
        // Permission is asked for when it is first useful (a break starting,
        // reminders being turned on), not on a cold launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) => onOpen?.call(),
    );
  }

  @override
  Future<bool> isPermitted() async {
    final android = _android;
    if (android != null) return await android.areNotificationsEnabled() ?? false;
    final ios = _ios;
    if (ios != null) return (await ios.checkPermissions())?.isEnabled ?? false;
    return false;
  }

  @override
  Future<bool> ensurePermission() async {
    if (await isPermitted()) return true;
    final android = _android;
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _ios;
    if (ios != null) return await ios.requestPermissions(alert: true, sound: true) ?? false;
    return false;
  }

  @override
  Future<bool> canRingOnTime() async {
    final android = _android;
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<void> requestRingOnTime() async {
    await _android?.requestExactAlarmsPermission();
  }

  @override
  Future<void> showBreak(ActiveBreak b, {required bool alarm, required DateTime now}) async {
    // The running timer: Android draws the count-up itself from `when`, so it
    // keeps ticking in the shade with the app asleep or gone.
    await _plugin.show(
      id: NotificationIds.breakTimer,
      title: 'Outside · ${b.title}',
      body: "Tap when you're back inside to log it.",
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'break_timer',
          'Break timer',
          channelDescription: 'The running timer while you are outside',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          usesChronometer: true,
          when: b.start.millisecondsSinceEpoch,
          category: AndroidNotificationCategory.stopwatch,
        ),
        iOS: const DarwinNotificationDetails(presentSound: false),
      ),
    );

    await _plugin.cancel(id: NotificationIds.questTime);
    await _plugin.cancel(id: NotificationIds.stillOutside);
    if (!alarm) return;
    final mode = await canRingOnTime()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    if (b.targetAt.isAfter(now)) {
      await _plugin.zonedSchedule(
        id: NotificationIds.questTime,
        scheduledDate: _instant(b.targetAt),
        notificationDetails: _questTime,
        androidScheduleMode: mode,
        title: 'Quest time reached 🌿',
        body: '${b.minutes} min outside. Stay as long as you like — tap when you are back to log it.',
      );
    }
    final checkIn = b.targetAt.add(stillOutsideAfter);
    if (checkIn.isAfter(now)) {
      await _plugin.zonedSchedule(
        id: NotificationIds.stillOutside,
        scheduledDate: _instant(checkIn),
        notificationDetails: _daily,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'Still outside?',
        body: '${Twiga.name} is still timing. Tap to log your break — '
            'one break counts for up to ${ActiveBreak.maxLength.inHours} hours.',
      );
    }
  }

  @override
  Future<void> clearBreak() async {
    await _plugin.cancel(id: NotificationIds.breakTimer);
    await _plugin.cancel(id: NotificationIds.questTime);
    await _plugin.cancel(id: NotificationIds.stillOutside);
  }

  @override
  Future<void> setDaily(List<PlannedReminder> plan) async {
    for (var slot = 0; slot < nudgeDaysAhead; slot++) {
      await _plugin.cancel(id: NotificationIds.dailyBase + slot);
    }
    for (final r in plan) {
      await _plugin.zonedSchedule(
        id: NotificationIds.dailyBase + r.slot,
        scheduledDate: _instant(r.at),
        notificationDetails: _daily,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
      );
    }
  }

  /// Each reminder is planned as a local wall-clock time and booked as the
  /// absolute instant it falls on, so no timezone database is needed. A trip
  /// across zones is picked up by the next re-plan (every launch and resume).
  static tz.TZDateTime _instant(DateTime local) => tz.TZDateTime.from(local, tz.UTC);
}
