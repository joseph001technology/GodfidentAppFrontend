import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';
import 'ringtone_store.dart';

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
      final timezone = await FlutterTimezone.getLocalTimezone();
      final String tzName = timezone.identifier;
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (e) {
      if (kDebugMode) {
        print('Could not initialize timezone: $e');
      }
      tz.setLocalLocation(tz.UTC);
    }

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

  AndroidNotificationSound _soundFor(Ringtone t) => t.isDevice
      ? UriAndroidNotificationSound(t.uri!)
      : RawResourceAndroidNotificationSound('godfident_${t.id}');

  // A channel's sound cannot change after it is created, so every
  // (kind, ringtone) pair gets its own channel.
  String _channelIdFor(Ringtone t, bool alarm) =>
      '${alarm ? 'alarm' : 'rem'}_${t.isDevice ? 'u${t.uri.hashCode.abs()}' : t.id}';

  AndroidNotificationDetails _androidDetails(Ringtone t, bool alarm) => AndroidNotificationDetails(
        _channelIdFor(t, alarm),
        alarm ? 'Alarms \u2013 ${t.title}' : 'Reminders \u2013 ${t.title}',
        channelDescription: alarm ? 'Loud alarm reminders' : 'Prayer, scripture and devotion reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: _soundFor(t),
        enableVibration: true,
        fullScreenIntent: alarm,
        category: alarm ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
        audioAttributesUsage: alarm ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
      );

  /// Schedules ONE local notification for [reminder] using its saved ringtone.
  /// Works with the app closed and with no internet. Returns true only if
  /// Android accepted the schedule.
  Future<bool> scheduleReminder(Reminder reminder) async {
    try {
      await initialize();
      final base = reminder.dateTime;
      if (base == null || !reminder.isEnabled || reminder.isCompleted) {
        await cancelReminder(reminder.id);
        return false;
      }

      final now = DateTime.now();
      var when = base;
      DateTimeComponents? match;
      switch (reminder.repeat) {
        case 'daily':
          while (!when.isAfter(now)) {
            when = when.add(const Duration(days: 1));
          }
          match = DateTimeComponents.time;
          break;
        case 'weekly':
          while (!when.isAfter(now)) {
            when = when.add(const Duration(days: 7));
          }
          match = DateTimeComponents.dayOfWeekAndTime;
          break;
        case 'monthly':
          while (!when.isAfter(now)) {
            when = DateTime(when.year, when.month + 1, when.day, when.hour, when.minute);
          }
          match = DateTimeComponents.dayOfMonthAndTime;
          break;
        default:
          // One-time reminder whose time has passed: nothing to schedule.
          if (!when.isAfter(now)) {
            await cancelReminder(reminder.id);
            return false;
          }
      }

      final tone = await RingtoneStore.instance.load(reminder.id);
      final details = NotificationDetails(
        android: _androidDetails(tone, reminder.isAlarm),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: reminder.isAlarm ? InterruptionLevel.timeSensitive : null,
        ),
      );

      // Exact delivery needs the "Alarms & reminders" permission; without it
      // fall back to inexact (a few minutes late) instead of failing silently.
      final exact = await Permission.scheduleExactAlarm.isGranted;
      await _plugin.zonedSchedule(
        reminder.id,
        reminder.title,
        reminder.description?.isNotEmpty == true ? reminder.description! : 'Time for your spiritual check-in',
        tz.TZDateTime.from(when, tz.local),
        details,
        androidScheduleMode:
            exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: match,
        payload: reminder.targetRoute,
      );
      return true;
    } catch (e) {
      if (kDebugMode) print('scheduleReminder failed: $e');
      return false;
    }
  }

  /// Fires a real notification immediately with the chosen sound (used by "Test").
  Future<void> showNow(Reminder reminder) async {
    await initialize();
    final tone = await RingtoneStore.instance.load(reminder.id);
    await _plugin.show(
      900000 + (reminder.id.abs() % 90000),
      reminder.title,
      reminder.description ?? 'Test reminder',
      NotificationDetails(android: _androidDetails(tone, reminder.isAlarm)),
      payload: reminder.targetRoute,
    );
  }

  Future<int> pendingCount() async => (await _plugin.pendingNotificationRequests()).length;

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
}
