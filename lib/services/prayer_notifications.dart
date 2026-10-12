import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer.dart';
import 'daily_activity.dart';
import 'native_alarm.dart';

/// "Remind me to pray for this" for ONE prayer request.
class PrayerReminderSetting {
  final int prayerId;
  final String title;
  final int hour;
  final int minute;
  final bool weekly;

  /// 1 = Monday ... 7 = Sunday (only used when [weekly]).
  final int weekday;

  /// true: rings like an alarm until stopped. false: a plain notification.
  final bool ring;

  const PrayerReminderSetting({
    required this.prayerId,
    required this.title,
    required this.hour,
    required this.minute,
    this.weekly = false,
    this.weekday = 1,
    this.ring = false,
  });

  Map<String, dynamic> toJson() => {
        'id': prayerId,
        'title': title,
        'h': hour,
        'm': minute,
        'weekly': weekly,
        'wd': weekday,
        'ring': ring,
      };

  static PrayerReminderSetting? fromJson(dynamic j) {
    if (j is! Map) return null;
    final id = (j['id'] as num?)?.toInt();
    if (id == null) return null;
    return PrayerReminderSetting(
      prayerId: id,
      title: '${j['title'] ?? ''}',
      hour: (j['h'] as num?)?.toInt() ?? 8,
      minute: (j['m'] as num?)?.toInt() ?? 0,
      weekly: j['weekly'] == true,
      weekday: ((j['wd'] as num?)?.toInt() ?? 1).clamp(1, 7),
      ring: j['ring'] == true,
    );
  }

  String describe() {
    final t = PrayerNotifications.formatTime(hour, minute);
    if (!weekly) return 'Every day at $t';
    return 'Every ${PrayerNotifications.weekdayName(weekday)} at $t';
  }
}

/// One of the (up to 3) "Daily prayer time" slots.
class DailyPrayerSlot {
  final bool on;
  final int hour;
  final int minute;
  const DailyPrayerSlot({required this.on, required this.hour, required this.minute});

  DailyPrayerSlot copyWith({bool? on, int? hour, int? minute}) =>
      DailyPrayerSlot(on: on ?? this.on, hour: hour ?? this.hour, minute: minute ?? this.minute);
}

class DailyPrayerSettings {
  final List<DailyPrayerSlot> slots;

  /// true: rings like an alarm. false: a plain notification.
  final bool ring;

  /// true: stay silent on days you have already prayed.
  final bool onlyIfNotPrayed;

  const DailyPrayerSettings({required this.slots, this.ring = false, this.onlyIfNotPrayed = false});

  DailyPrayerSettings copyWith({List<DailyPrayerSlot>? slots, bool? ring, bool? onlyIfNotPrayed}) =>
      DailyPrayerSettings(
        slots: slots ?? this.slots,
        ring: ring ?? this.ring,
        onlyIfNotPrayed: onlyIfNotPrayed ?? this.onlyIfNotPrayed,
      );

  bool get anyOn => slots.any((s) => s.on);
}

/// Prayer reminders that run from the phone's own alarm system (NativeAlarm), so
/// they work offline and with the app closed.
///
///  * Daily prayer times: up to 3 a day, ids 9190001..9190003.
///  * Per prayer request: id 9200000 + prayerId.
///
/// Call [ensureScheduled] at app start and whenever the prayer screens / Home load.
class PrayerNotifications {
  PrayerNotifications._();

  static const slotCount = 3;
  static const dailyBaseId = 9190000; // + slot index + 1
  static const prayerBaseId = 9200000; // + prayer id

  static const _kReminders = 'pn_prayer_reminders';
  static const _kRing = 'pn_daily_ring';
  static const _kSkip = 'pn_daily_skip';

  static const _defaultTimes = [(7, 0), (12, 30), (21, 0)];
  static const slotNames = ['Morning', 'Midday', 'Evening'];
  static const _slotBodies = [
    'Start your day with God. Give Him the first quiet minutes.',
    'Pause and pray. The Lord is near to all who call on Him.',
    'End the day with thanksgiving and prayer.',
  ];

  static int dailyId(int slot) => dailyBaseId + slot + 1;
  static int prayerAlarmId(int prayerId) => prayerBaseId + prayerId;

  static String formatTime(int hour, int minute) {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final ap = hour < 12 ? 'AM' : 'PM';
    return '$h12:${minute.toString().padLeft(2, '0')} $ap';
  }

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static String weekdayName(int weekday) => _weekdays[(weekday.clamp(1, 7)) - 1];

  /// Next time (after now) at [hour]:[minute]; on [weekday] (1..7) when given.
  static DateTime _next(int hour, int minute, {int? weekday}) {
    final now = DateTime.now();
    var when = DateTime(now.year, now.month, now.day, hour, minute);
    while (!when.isAfter(now) || (weekday != null && when.weekday != weekday)) {
      when = DateTime(when.year, when.month, when.day + 1, hour, minute);
    }
    return when;
  }

  // ── Daily prayer times ────────────────────────────────────────────

  static Future<DailyPrayerSettings> loadDaily() async {
    final slots = <DailyPrayerSlot>[];
    var ring = false;
    var skip = false;
    try {
      final p = await SharedPreferences.getInstance();
      for (var i = 0; i < slotCount; i++) {
        final def = _defaultTimes[i];
        final t = (p.getString('pn_daily_time_$i') ?? '${def.$1}:${def.$2}').split(':');
        slots.add(DailyPrayerSlot(
          on: p.getBool('pn_daily_on_$i') ?? false,
          hour: (int.tryParse(t[0]) ?? def.$1).clamp(0, 23),
          minute: (int.tryParse(t.length > 1 ? t[1] : '0') ?? 0).clamp(0, 59),
        ));
      }
      ring = p.getBool(_kRing) ?? false;
      skip = p.getBool(_kSkip) ?? false;
    } catch (_) {
      slots.clear();
      for (var i = 0; i < slotCount; i++) {
        slots.add(DailyPrayerSlot(on: false, hour: _defaultTimes[i].$1, minute: _defaultTimes[i].$2));
      }
    }
    return DailyPrayerSettings(slots: slots, ring: ring, onlyIfNotPrayed: skip);
  }

  /// Saves and (re)arms the daily prayer times.
  static Future<void> saveDaily(DailyPrayerSettings s) async {
    try {
      final p = await SharedPreferences.getInstance();
      for (var i = 0; i < s.slots.length && i < slotCount; i++) {
        await p.setBool('pn_daily_on_$i', s.slots[i].on);
        await p.setString('pn_daily_time_$i', '${s.slots[i].hour}:${s.slots[i].minute}');
      }
      await p.setBool(_kRing, s.ring);
      await p.setBool(_kSkip, s.onlyIfNotPrayed);
    } catch (e) {
      if (kDebugMode) print('PrayerNotifications.saveDaily failed: $e');
    }
    await _scheduleDaily(s);
  }

  static Future<void> _scheduleDaily(DailyPrayerSettings s) async {
    for (var i = 0; i < slotCount && i < s.slots.length; i++) {
      final slot = s.slots[i];
      final id = dailyId(i);
      if (!slot.on) {
        await NativeAlarm.cancel(id);
        continue;
      }
      await NativeAlarm.schedule(
        id: id,
        when: _next(slot.hour, slot.minute),
        repeat: const Duration(days: 1),
        title: 'Time to pray',
        body: _slotBodies[i],
        route: '/prayer/focus',
        sound: '',
        maxSeconds: 60,
        startLabel: 'Pray',
        ring: s.ring,
        skipKey: s.onlyIfNotPrayed ? DailyActivity.prayedKey : '',
      );
    }
  }

  // ── Per prayer request ────────────────────────────────────────────

  static Future<Map<String, dynamic>> _loadMap() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kReminders);
      if (raw == null || raw.isEmpty) return {};
      final d = jsonDecode(raw);
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return {};
  }

  static Future<void> _saveMap(Map<String, dynamic> m) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kReminders, jsonEncode(m));
    } catch (_) {}
  }

  static Future<PrayerReminderSetting?> getPrayerReminder(int prayerId) async {
    final m = await _loadMap();
    return PrayerReminderSetting.fromJson(m['$prayerId']);
  }

  /// All saved per-prayer reminders.
  static Future<List<PrayerReminderSetting>> allPrayerReminders() async {
    final m = await _loadMap();
    return [
      for (final v in m.values)
        if (PrayerReminderSetting.fromJson(v) != null) PrayerReminderSetting.fromJson(v)!,
    ];
  }

  /// Saves and arms "Remind me to pray for this".
  static Future<void> setPrayerReminder(PrayerReminderSetting r) async {
    final m = await _loadMap();
    m['${r.prayerId}'] = r.toJson();
    await _saveMap(m);
    await _schedulePrayer(r);
  }

  static Future<void> _schedulePrayer(PrayerReminderSetting r) async {
    await NativeAlarm.schedule(
      id: prayerAlarmId(r.prayerId),
      when: _next(r.hour, r.minute, weekday: r.weekly ? r.weekday : null),
      repeat: Duration(days: r.weekly ? 7 : 1),
      title: 'Pray for: ${r.title}',
      body: 'Take a moment to bring this before God.',
      route: '/prayer/${r.prayerId}',
      sound: '',
      maxSeconds: 60,
      startLabel: 'Pray',
      ring: r.ring,
    );
  }

  /// Removes the reminder of one prayer (deleted or answered).
  static Future<void> clearPrayerReminder(int prayerId) async {
    await NativeAlarm.cancel(prayerAlarmId(prayerId));
    final m = await _loadMap();
    if (m.remove('$prayerId') != null) await _saveMap(m);
  }

  /// Cancels reminders of prayers that no longer exist or are already answered.
  static Future<void> syncWithPrayers(List<Prayer> prayers) async {
    try {
      final active = <int>{for (final p in prayers) if (p.isActive) p.id};
      for (final r in await allPrayerReminders()) {
        if (!active.contains(r.prayerId)) await clearPrayerReminder(r.prayerId);
      }
    } catch (_) {}
  }

  // ── Everything ────────────────────────────────────────────────────

  /// Re-arms the daily prayer times and every per-prayer reminder. Cheap and
  /// safe to call often (app start, Home, prayer screens). Never throws.
  static Future<void> ensureScheduled() async {
    try {
      await _scheduleDaily(await loadDaily());
      for (final r in await allPrayerReminders()) {
        await _schedulePrayer(r);
      }
    } catch (e) {
      if (kDebugMode) print('PrayerNotifications.ensureScheduled failed: $e');
    }
  }
}
