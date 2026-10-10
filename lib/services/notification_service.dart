import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';
import '../models/scheduled_focus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'daily_activity.dart';
import 'fasting_log.dart';
import 'native_alarm.dart';
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

  /// Sound argument for [NativeAlarm]: bundled tone, phone song, or default alarm tone.
  String _nativeSound(Ringtone t) => t.isDevice ? t.uri! : 'raw:godfident_${t.id}';

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
      final bodyText = reminder.description?.isNotEmpty == true ? reminder.description! : 'Time for your spiritual check-in';
      final soundArg = reminder.isAlarm ? _nativeSound(tone) : (tone.isDevice ? tone.uri! : 'raw:godfident_${tone.id}');

      // Days of the week ("every Monday and Thursday"): one repeating phone alarm per day.
      final days = reminder.repeat == 'weekly' ? reminder.weekdays : const <int>[];
      if (days.isNotEmpty) {
        await NativeAlarm.cancel(reminder.id);
        var all = true;
        for (final wd in days) {
          final okDay = await NativeAlarm.schedule(
            id: dayAlarmId(reminder.id, wd),
            when: _nextWeekday(wd, base.hour, base.minute),
            repeat: const Duration(days: 7),
            title: reminder.title,
            body: bodyText,
            route: reminder.targetRoute,
            sound: soundArg,
            maxSeconds: 120,
            ring: reminder.isAlarm,
          );
          all = all && okDay;
        }
        await _scheduleFastingCheckins(reminder, days);
        return all;
      }

      // Everything is scheduled by the phone itself (AlarmManager), so it works
      // with no internet, with the app closed and after a restart. Alarms ring
      // from a native service; plain reminders are native notifications.
      final ok = await NativeAlarm.schedule(
        id: reminder.id,
        when: when,
        repeat: reminder.repeat == 'daily'
            ? const Duration(days: 1)
            : reminder.repeat == 'weekly'
                ? const Duration(days: 7)
                : reminder.repeat == 'monthly'
                    ? const Duration(milliseconds: -1) // native side: "monthly"
                    : Duration.zero,
        title: reminder.title,
        body: bodyText,
        route: reminder.targetRoute,
        sound: soundArg,
        maxSeconds: 120,
        ring: reminder.isAlarm,
      );
      if (ok) await _scheduleFastingCheckins(reminder, const <int>[]);
      if (ok) {
        try {
          await _plugin.cancel(reminder.id); // drop any old plugin copy so it never fires twice
        } catch (_) {}
        return true;
      }

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

  /// Alarm id for one weekday (1 = Monday ... 7 = Sunday) of a reminder.
  static int dayAlarmId(int id, int wd) => 1700000000 + (id.abs() % 1000000) * 10 + wd;

  /// Id of the "Did you fast?" question for a weekday (0 = a one-off reminder).
  static int checkinId(int id, int wd) => 1720000000 + (id.abs() % 1000000) * 10 + wd;

  DateTime _nextWeekday(int wd, int hour, int minute) {
    final now = DateTime.now();
    for (var i = 0; i < 8; i++) {
      final d = DateTime(now.year, now.month, now.day + i, hour, minute);
      if (d.weekday == wd && d.isAfter(now)) return d;
    }
    return DateTime(now.year, now.month, now.day + 7, hour, minute);
  }

  /// A fasting reminder also asks "Did you fast today?" at the time chosen for it.
  Future<void> _scheduleFastingCheckins(Reminder r, List<int> days) async {
    for (var wd = 0; wd <= 7; wd++) {
      await NativeAlarm.cancel(checkinId(r.id, wd));
    }
    if (r.kind != 'fasting') return;
    final ask = await FastingLog.askTime(r.id);
    final now = DateTime.now();
    final slots = days.isEmpty ? <int>[0] : days;
    for (final wd in slots) {
      DateTime when;
      if (wd == 0) {
        final d = r.dateTime ?? now;
        when = DateTime(d.year, d.month, d.day, ask.hour, ask.minute);
        if (r.repeat == 'daily') {
          while (!when.isAfter(now)) {
            when = when.add(const Duration(days: 1));
          }
        } else if (!when.isAfter(now)) {
          continue;
        }
      } else {
        when = _nextWeekday(wd, ask.hour, ask.minute);
      }
      await NativeAlarm.schedule(
        id: checkinId(r.id, wd),
        when: when,
        repeat: wd == 0 && r.repeat != 'daily' ? Duration.zero : (wd == 0 ? const Duration(days: 1) : const Duration(days: 7)),
        title: 'Did you fast today?',
        body: '${r.title}: tap to answer Yes or No.',
        route: '/fasting-checkin?id=${r.id}&title=${Uri.encodeComponent(r.title)}',
        sound: '',
        maxSeconds: 60,
        ring: false,
      );
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

  // ── Scheduled Focus sessions ───────────────────────────────────────
  // Ring tone for session [id] is kept in RingtoneStore under this key so it
  // can never collide with a reminder id.
  static int focusRingtoneKey(int id) => 5000000 + id;

  // 8 slots per session: 1..7 = weekday, 0 = one-time. Heads-up uses +400000.
  static int _focusNotifId(int id, int slot) => 800000 + id * 10 + slot;
  static int _focusHeadsUpId(int id, int slot) => 1200000 + id * 10 + slot;

  /// Where tapping the ringing notification (or its Start button) goes.
  static String focusRoute(int id) => '/focus?start=$id';

  Future<void> cancelFocusSession(int id) async {
    for (var slot = 0; slot <= 7; slot++) {
      await cancelReminder(_focusNotifId(id, slot));
      await cancelReminder(_focusHeadsUpId(id, slot));
    }
  }

  tz.TZDateTime _nextFocusInstance(int? weekday, int hour, int minute, {int shiftMinutes = 0}) {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute).add(Duration(minutes: shiftMinutes));
    // Find the first instance in the future that falls on [weekday] (any day if null).
    for (var i = 0; i < 16; i++) {
      final base = tz.TZDateTime(tz.local, now.year, now.month, now.day + i, hour, minute);
      d = base.add(Duration(minutes: shiftMinutes));
      final dayOk = weekday == null || base.weekday == weekday;
      if (dayOk && d.isAfter(now)) return d;
    }
    return d;
  }

  /// Schedules the ringing alarm (and a quiet 5-minute heads-up) for a
  /// pre-set Focus session. The alarm uses FLAG_INSISTENT: the ringtone keeps
  /// repeating, and the notification cannot be swiped away, until the user
  /// presses Start (it gives up after 30 minutes so it never rings all day).
  Future<bool> scheduleFocusSession(ScheduledFocus f) async {
    try {
      await initialize();
      await cancelFocusSession(f.id);
      if (!f.enabled) return true;

      final tone = await RingtoneStore.instance.load(focusRingtoneKey(f.id));
      final ring = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdFor(tone, true),
          'Alarms \u2013 ${tone.title}',
          channelDescription: 'Loud alarm reminders',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: _soundFor(tone),
          enableVibration: true,
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
          timeoutAfter: 30 * 60 * 1000,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT: keep ringing
          actions: const [
            AndroidNotificationAction('focus_start', 'Start', showsUserInterface: true),
          ],
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true, interruptionLevel: InterruptionLevel.timeSensitive),
      );
      const headsUp = NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId,
          _reminderChannelName,
          channelDescription: _reminderChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      );

      final exact = await Permission.scheduleExactAlarm.isGranted;
      final mode = exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
      final slots = f.days.isEmpty ? <int?>[null] : f.days.cast<int?>();

      for (final wd in slots) {
        final slot = wd ?? 0;
        final match = wd == null ? null : DateTimeComponents.dayOfWeekAndTime;
        final first = _nextFocusInstance(wd, f.hour, f.minute);
        // The ringing itself: native service, keeps ringing until Start / Stop.
        final nativeOk = await NativeAlarm.schedule(
          id: _focusNotifId(f.id, slot),
          when: first,
          repeat: wd == null ? Duration.zero : const Duration(days: 7),
          title: 'Your time with God is starting',
          body: '${f.displayTitle} \u00b7 ${f.durationLabel}. Press Start to begin your Focus session.',
          route: focusRoute(f.id),
          sound: _nativeSound(tone),
          maxSeconds: 30 * 60,
          startLabel: 'Start',
        );
        if (!nativeOk) {
          await _plugin.zonedSchedule(
            _focusNotifId(f.id, slot),
            'Your time with God is starting',
            '${f.displayTitle} \u00b7 ${f.durationLabel}. Press Start to begin your Focus session.',
            first,
            ring,
            androidScheduleMode: mode,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: match,
            payload: focusRoute(f.id),
          );
        }
        // 5 minutes before. Its weekday may differ from [wd] when it crosses midnight.
        final before = _nextFocusInstance(wd, f.hour, f.minute, shiftMinutes: -5);
        await _plugin.zonedSchedule(
          _focusHeadsUpId(f.id, slot),
          'Focus session in 5 minutes',
          '${f.displayTitle} starts at ${f.timeLabel}.',
          before,
          headsUp,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: wd == null ? null : DateTimeComponents.dayOfWeekAndTime,
          payload: focusRoute(f.id),
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('scheduleFocusSession failed: $e');
      return false;
    }
  }

  /// Stops the ringing for [f] after Start is pressed, then re-arms its future
  /// occurrences (cancelling a notification id also removes its repeat).
  Future<void> silenceFocusRing(ScheduledFocus f) async {
    await NativeAlarm.stopSound();
    await cancelFocusSession(f.id);
    if (f.days.isNotEmpty) await scheduleFocusSession(f);
  }

  /// Route of the notification that launched the app from a cold start, if any.
  Future<String?> launchPayload() async {
    try {
      await initialize();
      final d = await _plugin.getNotificationAppLaunchDetails();
      if (d?.didNotificationLaunchApp ?? false) return d?.notificationResponse?.payload;
    } catch (_) {}
    return null;
  }

  // ── "Your session has ended" ────────────────────────────────────────
  static const _focusEndId = 700001;

  /// Schedules a notification for the moment a Focus / Prayer session ends,
  /// so it arrives even if the app is closed. Cancel it if the session is
  /// ended early.
  Future<void> scheduleFocusEnd(DateTime endAt, {String purpose = '', String route = '/focus'}) async {
    try {
      await initialize();
      await _plugin.cancel(_focusEndId);
      if (!endAt.isAfter(DateTime.now())) return;
      final what = purpose == 'prayer' ? 'prayer' : purpose == 'bible' ? 'Bible reading' : 'Focus';
      final exact = await Permission.scheduleExactAlarm.isGranted;
      await _plugin.zonedSchedule(
        _focusEndId,
        'Your $what session has ended',
        'Well done. Your time with God is recorded.',
        tz.TZDateTime.from(endAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'focus_end',
            'Session finished',
            channelDescription: 'Tells you when a Focus or Prayer session is over',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: route,
      );
    } catch (e) {
      if (kDebugMode) print('scheduleFocusEnd failed: $e');
    }
  }

  // ── Always-visible session timer ───────────────────────────────────
  // An ongoing notification with a live countdown that the phone itself keeps
  // ticking, so a Focus / Prayer session is visible in the notification shade
  // and on the lock screen from any app, even when Godfident is closed.
  static const _timerId = 700002;

  Future<void> showSessionTimer({
    required DateTime endAt,
    String purpose = '',
    String route = '/focus',
    bool frozen = false,
    Duration frozenLeft = Duration.zero,
  }) async {
    try {
      await initialize();
      final what = purpose == 'prayer' ? 'Prayer time' : purpose == 'bible' ? 'Bible time' : purpose == 'both' ? 'Time with God' : 'Focus time';
      final left = endAt.difference(DateTime.now());
      if (!frozen && left.isNegative) return;
      final mins = frozen ? (frozenLeft.inMinutes < 1 ? 1 : frozenLeft.inMinutes) : 0;
      await _plugin.show(
        _timerId,
        frozen ? '$what is frozen' : '$what is running',
        frozen ? "$mins min still to go. Tap to resume \u2014 you haven't finished." : 'Time left with God. Stay with it \u2014 tap to return.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'session_timer',
            'Session timer',
            channelDescription: 'Shows the time left in a running Focus or Prayer session',
            importance: Importance.low,
            priority: Priority.high,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
            showWhen: !frozen,
            when: frozen ? null : endAt.millisecondsSinceEpoch,
            usesChronometer: !frozen,
            chronometerCountDown: !frozen,
            timeoutAfter: frozen ? null : left.inMilliseconds + 2000,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.progress,
            ticker: 'Session running',
          ),
          iOS: const DarwinNotificationDetails(presentAlert: false, presentSound: false),
        ),
        payload: route,
      );
    } catch (e) {
      if (kDebugMode) print('showSessionTimer failed: $e');
    }
  }

  Future<void> cancelSessionTimer() async {
    try {
      await _plugin.cancel(_timerId);
    } catch (_) {}
  }

  // ── "You haven't finished your session" every 10 minutes while frozen ──
  static const _focusNagBase = 700100;
  static const _nagCount = 12; // two hours of nudges

  Future<void> scheduleFocusNags({required Duration left, String route = '/focus'}) async {
    try {
      await initialize();
      await cancelFocusNags();
      final exact = await Permission.scheduleExactAlarm.isGranted;
      final mins = left.inMinutes < 1 ? 1 : left.inMinutes;
      for (var i = 1; i <= _nagCount; i++) {
        await _plugin.zonedSchedule(
          _focusNagBase + i,
          'Your Focus session is frozen',
          "You haven't finished yet \u2014 about $mins min still to go. Come back and resume your time with God.",
          tz.TZDateTime.now(tz.local).add(Duration(minutes: 10 * i)),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'focus_nag',
              'Unfinished Focus session',
              channelDescription: 'Every 10 minutes while a Focus session is frozen',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
            ),
            iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
          ),
          androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: route,
        );
      }
    } catch (e) {
      if (kDebugMode) print('scheduleFocusNags failed: $e');
    }
  }

  Future<void> cancelFocusNags() async {
    try {
      for (var i = 1; i <= _nagCount; i++) {
        await _plugin.cancel(_focusNagBase + i);
      }
    } catch (_) {}
  }

  // ── "You haven't prayed / read today" nudges ───────────────────────
  static const prayerNudgeId = 9100001;
  static const readNudgeId = 9100002;

  static Future<({bool on, int hour, int minute})> nudgeSetting(String which) async {
    final p = await SharedPreferences.getInstance();
    final on = p.getBool('nudge_${which}_on') ?? true;
    final t = (p.getString('nudge_${which}_time') ?? (which == 'prayer' ? '20:00' : '19:00')).split(':');
    return (on: on, hour: int.tryParse(t[0]) ?? 20, minute: int.tryParse(t.length > 1 ? t[1] : '0') ?? 0);
  }

  static Future<void> saveNudge(String which, {bool? on, int? hour, int? minute}) async {
    final p = await SharedPreferences.getInstance();
    if (on != null) await p.setBool('nudge_${which}_on', on);
    if (hour != null && minute != null) {
      await p.setString('nudge_${which}_time', '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
    }
  }

  /// Every day at the chosen time: if you have not prayed / read yet today you get a
  /// notification. If you already did, it stays silent. Runs from the phone's alarm
  /// system, so it works offline and after a restart (missed ones follow the same
  /// "ring if < 1 hour late, else say it was missed" rule).
  Future<void> scheduleDailyNudges() async {
    for (final which in const ['prayer', 'read']) {
      final id = which == 'prayer' ? prayerNudgeId : readNudgeId;
      final st = await nudgeSetting(which);
      if (!st.on) {
        await NativeAlarm.cancel(id);
        continue;
      }
      final now = DateTime.now();
      var when = DateTime(now.year, now.month, now.day, st.hour, st.minute);
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
      await NativeAlarm.schedule(
        id: id,
        when: when,
        repeat: const Duration(days: 1),
        title: which == 'prayer' ? "You haven't prayed today" : "You haven't read the Bible today",
        body: which == 'prayer'
            ? 'Take a few quiet minutes with God before the day ends.'
            : 'Open the Bible and read a chapter. God has a word for you today.',
        route: which == 'prayer' ? '/prayer/focus' : '/bible',
        sound: '',
        maxSeconds: 60,
        ring: false,
        skipKey: which == 'prayer' ? DailyActivity.prayedKey : DailyActivity.readKey,
      );
    }
  }

  /// Asks for what Android needs for reminders to reach you. Safe to call at every start.
  Future<void> ensureReminderPermissions() async {
    try {
      if (!await Permission.notification.isGranted) await Permission.notification.request();
    } catch (_) {}
  }

  Future<void> cancelFocusEnd() async {
    try {
      await _plugin.cancel(_focusEndId);
    } catch (_) {}
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

  /// Never throws. A failure to cancel an OS notification must not stop the
  /// caller from saving, toggling or DELETING the reminder on the server (it
  /// used to: one PlatformException here meant the delete request never ran).
  Future<bool> cancelReminder(int id) async {
    try {
      await NativeAlarm.cancel(id);
      for (var wd = 1; wd <= 7; wd++) {
        await NativeAlarm.cancel(dayAlarmId(id, wd));
      }
      for (var wd = 0; wd <= 7; wd++) {
        await NativeAlarm.cancel(checkinId(id, wd));
      }
      await _plugin.cancel(id);
      return true;
    } catch (e) {
      if (kDebugMode) print('cancelReminder($id) failed: $e');
      return false;
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      if (kDebugMode) print('cancelAll failed: $e');
    }
  }
}
