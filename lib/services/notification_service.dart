import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../models/reminder.dart';

/// Service for scheduling, pop-up displaying, and managing local notifications and alarms.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _reminderChannelId = 'godfident_reminders';
  static const _reminderChannelName = 'Spiritual Reminders';
  static const _reminderChannelDesc = 'Prayer, scripture reading, and devotion reminders';

  static const _alarmChannelId = 'godfident_alarms';
  static const _alarmChannelName = 'Spiritual Alarms';
  static const _alarmChannelDesc = 'High-priority spiritual alarm notifications with ringtone';

  final _selectNotificationController = StreamController<String>.broadcast();
  Stream<String> get onNotificationTap => _selectNotificationController.stream;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _selectNotificationController.add(payload);
        }
      },
    );

    // Create high-importance reminder channel for pop-up notifications
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _reminderChannelId,
            _reminderChannelName,
            description: _reminderChannelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

    // Create alarm channel with ringtone audio attributes
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _alarmChannelId,
            _alarmChannelName,
            description: _alarmChannelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );

    _initialized = true;
    await requestPermissions();
  }

  Future<void> requestPermissions() async {
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      // On Android 12+, exact alarms require permission
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    } catch (_) {}
  }

  /// Schedule or update a reminder locally (works completely offline).
  Future<void> scheduleReminder(Reminder reminder) async {
    await initialize();

    if (!reminder.isEnabled || reminder.isCompleted) {
      await cancelNotification(reminder.id);
      return;
    }

    final targetDateTime = _calculateNextOccurrence(reminder);
    if (targetDateTime == null) return;

    final payload = reminder.targetRoute;
    final title = reminder.title;
    final body = reminder.description ?? 'Time for your spiritual check-in';

    final notificationDetails = _buildNotificationDetails(
      isAlarm: reminder.isAlarm,
      title: title,
      body: body,
    );

    await cancelNotification(reminder.id);

    final tzDateTime = tz.TZDateTime.from(targetDateTime, tz.local);

    if (reminder.repeat == 'daily') {
      await _plugin.periodicallyShow(
        reminder.id,
        title,
        body,
        RepeatInterval.daily,
        notificationDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } else if (reminder.repeat == 'weekly') {
      await _plugin.periodicallyShow(
        reminder.id,
        title,
        body,
        RepeatInterval.weekly,
        notificationDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } else {
      // One-time or Once
      if (tzDateTime.isBefore(tz.TZDateTime.now(tz.local))) return;
      await _plugin.zonedSchedule(
        reminder.id,
        title,
        body,
        tzDateTime,
        notificationDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Immediately trigger a preview notification for testing settings/sounds.
  Future<void> previewNotification(Reminder reminder) async {
    await initialize();
    final details = _buildNotificationDetails(
      isAlarm: reminder.isAlarm,
      title: reminder.title,
      body: reminder.description ?? 'Test preview notification',
    );

    await _plugin.show(
      999900 + reminder.id,
      '🔔 Preview: ${reminder.title}',
      reminder.description ?? 'This is how your reminder will appear.',
      details,
      payload: reminder.targetRoute,
    );
  }

  NotificationDetails _buildNotificationDetails({
    required bool isAlarm,
    required String title,
    required String body,
  }) {
    if (isAlarm) {
      return const NotificationDetails(
        android: AndroidNotificationDetails(
          _alarmChannelId,
          _alarmChannelName,
          channelDescription: _alarmChannelDesc,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );
    }

    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _reminderChannelId,
        _reminderChannelName,
        channelDescription: _reminderChannelDesc,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
      ),
    );
  }

  DateTime? _calculateNextOccurrence(Reminder reminder) {
    final now = DateTime.now();
    int hour = 8;
    int minute = 0;

    if (reminder.time != null && reminder.time!.isNotEmpty) {
      final parts = reminder.time!.split(':');
      if (parts.length >= 2) {
        hour = int.tryParse(parts[0]) ?? 8;
        minute = int.tryParse(parts[1]) ?? 0;
      }
    }

    DateTime target;
    if (reminder.date.isNotEmpty) {
      try {
        final d = DateTime.parse(reminder.date);
        target = DateTime(d.year, d.month, d.day, hour, minute);
      } catch (_) {
        target = DateTime(now.year, now.month, now.day, hour, minute);
      }
    } else {
      target = DateTime(now.year, now.month, now.day, hour, minute);
    }

    // If target is in the past for repeating reminders, shift to future
    if (target.isBefore(now)) {
      if (reminder.repeat == 'daily') {
        target = target.add(const Duration(days: 1));
      } else if (reminder.repeat == 'weekly') {
        target = target.add(const Duration(days: 7));
      }
    }

    return target;
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

