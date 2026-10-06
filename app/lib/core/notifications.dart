import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'lesson_reminders.dart';

/// Android's notifications, set up once for the whole app.
class Notifications {
  Notifications._();
  static final plugin = FlutterLocalNotificationsPlugin();
  static Future<void>? _ready;

  /// Only the Android app shows them.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// What a tapped notification asks to open ('mail', 'lesson'), until the
  /// app has.
  static final tapped = ValueNotifier<String?>(null);

  static AndroidFlutterLocalNotificationsPlugin? get android =>
      plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> ensureReady() => _ready ??= plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_lesson'),
        ),
        onDidReceiveNotificationResponse: (r) => tapped.value = r.payload,
      );

  /// At launch: set up, and see whether a notification opened the app.
  static Future<void> start() async {
    await ensureReady();
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      tapped.value = launch!.notificationResponse?.payload;
    }
  }

  /// Asks to show notifications (Android 13+ asks the user); true when
  /// allowed.
  static Future<bool> requestPermission() async {
    await ensureReady();
    return await android?.requestNotificationsPermission() ?? false;
  }
}

/// Lesson reminders as Android notifications at set times. Android keeps
/// them through a restart (the boot receiver in AndroidManifest.xml).
class LocalReminderPlatform implements ReminderPlatform {
  static const _payload = 'lesson';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'lessons',
      'Напоминания о занятиях',
      channelDescription: 'Перед началом пары',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_lesson',
      category: AndroidNotificationCategory.reminder,
    ),
  );

  @override
  Future<bool> requestPermission() => Notifications.requestPermission();

  @override
  Future<void> replace(List<LessonReminder> reminders) async {
    await Notifications.ensureReady();
    final plugin = Notifications.plugin;
    for (final p in await plugin.pendingNotificationRequests()) {
      if (p.payload == _payload) await plugin.cancel(id: p.id);
    }
    if (reminders.isEmpty) return;
    // On time when Android allows it; otherwise within a few minutes.
    final exact =
        await Notifications.android?.canScheduleExactNotifications() ?? false;
    for (final r in reminders) {
      await plugin.zonedSchedule(
        id: r.id,
        scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
        payload: _payload,
      );
    }
    debugPrint('lesson reminders: ${reminders.length} planned'
        '${exact ? '' : ' (inexact)'}');
  }
}
