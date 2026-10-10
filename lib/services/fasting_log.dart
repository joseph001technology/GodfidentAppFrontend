import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers to "Did you fast today?". Kept on the phone (works offline) and used
/// by the weekly summary in My Activity.
class FastingLog {
  FastingLog._();
  static const _k = 'fasting_log_v1';

  static String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// When the "Did you fast today?" question arrives for reminder [id] (default 8 pm).
  static Future<({int hour, int minute})> askTime(int id) async {
    final p = await SharedPreferences.getInstance();
    final t = (p.getString('fast_ask_$id') ?? p.getString('fast_ask_default') ?? '20:00').split(':');
    return (hour: int.tryParse(t[0]) ?? 20, minute: int.tryParse(t.length > 1 ? t[1] : '0') ?? 0);
  }

  static Future<void> setAskTime(int id, int hour, int minute) async {
    final p = await SharedPreferences.getInstance();
    final v = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    await p.setString('fast_ask_$id', v);
    await p.setString('fast_ask_default', v); // the next fasting reminder starts with this time
  }

  static Future<List<Map<String, dynamic>>> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_k);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves the answer for [date] (a later answer for the same day and reminder replaces the earlier one).
  static Future<void> record({required DateTime date, required bool fasted, int reminderId = 0, String title = ''}) async {
    final list = await _load();
    final d = ymd(date);
    list.removeWhere((e) => e['d'] == d && e['id'] == reminderId);
    list.add({'d': d, 'id': reminderId, 't': title, 'did': fasted});
    if (list.length > 800) list.removeRange(0, list.length - 800);
    await (await SharedPreferences.getInstance()).setString(_k, jsonEncode(list));
  }

  /// Fasting answers from Monday of this week until today.
  static Future<({int fasted, int missed})> thisWeek() async {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final from = ymd(monday);
    var fasted = 0, missed = 0;
    for (final e in await _load()) {
      if ((e['d'] as String).compareTo(from) < 0) continue;
      e['did'] == true ? fasted++ : missed++;
    }
    return (fasted: fasted, missed: missed);
  }

  /// Days (yyyy-MM-dd) with at least one "I fasted" answer.
  static Future<Set<String>> fastedDays() async => {
        for (final e in await _load())
          if (e['did'] == true) e['d'] as String,
      };
}
