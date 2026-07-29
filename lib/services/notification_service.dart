import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Service for scheduling and displaying local notifications for reminders.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'godfident_reminders';
  static const _channelName = 'Spiritual Reminders';
  static const _channelDesc = 'Prayer, scripture reading, and devotion reminders';

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {},
    );

    await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
      const AndroidNotificationChannel(_channelId, _channelName,
        description: _channelDesc, importance: Importance.high),
    );
    _initialized = true;
  }

  Future<void> scheduleDailyReminder({required int id, required String title, required String body}) async {
    await initialize();
    await _plugin.periodicallyShow(id, title, body, RepeatInterval.daily,
      const NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName,
          channelDescription: _channelDesc, importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> scheduleOneTimeReminder({required int id, required String title, required String body, required DateTime scheduledDate}) async {
    await initialize();
    if (scheduledDate.isBefore(DateTime.now())) return;
    await _plugin.zonedSchedule(id, title, body, tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName,
          channelDescription: _channelDesc, importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
  Future<void> scheduleWeeklyReminder({required int id, required String title, required String body}) async {
    await initialize();
    await _plugin.periodicallyShow(id, title, body, RepeatInterval.weekly,
      const NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName,
          channelDescription: _channelDesc, importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

