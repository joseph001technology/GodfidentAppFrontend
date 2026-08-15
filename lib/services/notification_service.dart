import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  void Function(String? payload)? _onNotificationTap;

  static const _reminderChannelId = 'godfident_reminders';
  static const _reminderChannelName = 'Spiritual Reminders';
  static const _reminderChannelDesc = 'Prayer, scripture reading, and devotion reminders';

  static const _alarmChannelId = 'godfident_alarms';
  static const _alarmChannelName = 'Spiritual Alarms';
  static const _alarmChannelDesc = 'High-priority spiritual alarm notifications with ringtone';

  final _selectNotificationController = StreamController<String>.broadcast();
  Stream<String> get onNotificationTap => _selectNotificationController.stream;

  Future<void> initialize() async => init();

  Future<void> init({void Function(String? payload)? onNotificationTap}) async {
    if (_initialized) {
      _onNotificationTap = onNotificationTap ?? _onNotificationTap;
      return;
    }

    _onNotificationTap = onNotificationTap;

    try {
      tz_data.initializeTimeZones();
      final String tzName = await FlutterNativeTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (e) {
      if (kDebugMode) {
        print('Could not initialize timezone: $e');
      }
      tz.setLocalLocation(tz.UTC);
    }

    try {
      await Permission.notification.request();
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    } catch (_) {}

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _selectNotificationController.add(payload);
          _onNotificationTap?.call(payload);
        }
      },
    );

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
  }

  Future<void> requestPermissions() async {
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    } catch (_) {}
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _reminderChannelId,
        _reminderChannelName,
        channelDescription: _reminderChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
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
    await _plugin.show(id, title, body, details, payload: payload);
  }

  Future<void> previewNotification(Reminder reminder) async {
    await showNotification(
      id: 999900 + reminder.id,
      title: '🔔 Preview: ${reminder.title}',
      body: reminder.description ?? 'This is how your reminder will appear.',
      payload: reminder.targetRoute,
    );
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    await initialize();
    if (reminder.dateTime == null || !reminder.isEnabled || reminder.isCompleted) {
      await cancelReminder(reminder.id);
      return;
    }

    final scheduled = tz.TZDateTime.from(reminder.dateTime!.toLocal(), tz.local);
    final id = reminder.id;
    final payload = reminder.targetRoute;
    final title = reminder.title;
    final body = reminder.description ?? 'Time for your spiritual check-in';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        reminder.isAlarm ? _alarmChannelId : _reminderChannelId,
        reminder.isAlarm ? _alarmChannelName : _reminderChannelName,
        channelDescription: reminder.isAlarm ? _alarmChannelDesc : _reminderChannelDesc,
        importance: Importance.max,
        priority: reminder.isAlarm ? Priority.max : Priority.high,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: reminder.isAlarm,
        category: reminder.isAlarm ? AndroidNotificationCategory.alarm : null,
        ongoing: reminder.isAlarm,
        autoCancel: !reminder.isAlarm,
        audioAttributesUsage: reminder.isAlarm ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        interruptionLevel: reminder.isAlarm ? InterruptionLevel.timeSensitive : null,
      ),
    );

    final nextDate = reminder.repeat == 'daily'
        ? _nextInstanceOfTime(scheduled)
        : reminder.repeat == 'weekly'
            ? _nextInstanceOfTime(scheduled)
            : scheduled.isBefore(tz.TZDateTime.now(tz.local))
                ? _nextInstanceOfTime(scheduled)
                : scheduled;

    if (reminder.repeat == 'daily') {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        nextDate,
        details,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
      return;
    }

    if (reminder.repeat == 'weekly') {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        nextDate,
        details,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payload,
      );
      return;
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      nextDate,
      details,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> scheduleAlarm(Reminder reminder) async {
    final alarmReminder = reminder.copyWith(isAlarm: true);
    await scheduleReminder(alarmReminder);
  }

  Future<void> showAlarmNow(Reminder reminder) async {
    await showNotification(
      id: reminder.id,
      title: reminder.title,
      body: reminder.description ?? 'Alarm',
      payload: reminder.targetRoute,
    );
  }

  Future<void> cancelNotification(int id) async => cancelReminder(id);

  Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfTime(tz.TZDateTime dt) {
    final now = tz.TZDateTime.now(tz.local);
    if (dt.isAfter(now)) return dt;
    return tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      dt.hour,
      dt.minute,
    ).add(const Duration(days: 1));
  }
}
