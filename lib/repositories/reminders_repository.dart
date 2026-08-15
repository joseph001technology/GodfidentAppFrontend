import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/dio_client.dart';
import '../core/api_response.dart';
import '../models/reminder.dart';
import '../services/notification_service.dart';

class RemindersRepository {
  final _dio = DioClient.instance;
  static const _localKey = 'godfident_offline_reminders';

  Future<List<Reminder>> getList({
    String? date,
    int? category,
    bool? completed,
    String? search,
    String ordering = 'date,time',
  }) async {
    try {
      final res = await _dio.get('/api/reminders/', queryParameters: {
        if (date != null) 'date': date,
        if (category != null) 'category': category,
        if (completed != null) 'is_completed': completed,
        if (search != null) 'search': search,
        'ordering': ordering,
      });
      final list = (readList(res.data)).map((j) => Reminder.fromJson(j)).toList();
      await _saveLocal(list);
      // Sync notification schedules for active reminders
      for (final r in list) {
        if (r.isActive) {
          NotificationService().scheduleReminder(r);
        }
      }
      return list;
    } catch (_) {
      // Fallback to local offline storage
      return await getLocalList();
    }
  }

  Future<List<Reminder>> getLocalList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_localKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List raw = jsonDecode(jsonStr);
      return raw.map((j) => Reminder.fromJson(Map<String, dynamic>.from(j))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocal(List<Reminder> list) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = list.map((r) => r.toJson()).toList();
    await prefs.setString(_localKey, jsonEncode(raw));
  }

  Future<Reminder> getDetail(int id) async {
    try {
      final res = await _dio.get('/api/reminders/$id/');
      return Reminder.fromJson(res.data['data'] ?? res.data);
    } catch (_) {
      final list = await getLocalList();
      return list.firstWhere((r) => r.id == id, orElse: () => throw Exception('Reminder not found'));
    }
  }

  Future<Reminder> create(Map<String, dynamic> data) async {
    Reminder reminder;
    try {
      final res = await _dio.post('/api/reminders/', data: data);
      reminder = Reminder.fromJson(res.data);
    } catch (_) {
      final localId = DateTime.now().millisecondsSinceEpoch % 1000000;
      final nowStr = DateTime.now().toIso8601String().split('T').first;
      reminder = Reminder(
        id: localId,
        title: data['title'] ?? 'New Reminder',
        description: data['description'],
        date: data['date'] ?? nowStr,
        time: data['time'] ?? '08:00',
        repeat: data['repeat'] ?? 'none',
        isEnabled: data['is_enabled'] ?? true,
        isAlarm: data['is_alarm'] ?? false,
        targetPage: data['target_page'] ?? 'general',
        createdAt: DateTime.now().toIso8601String(),
      );
    }

    // Save locally and schedule
    final list = await getLocalList();
    list.insert(0, reminder);
    await _saveLocal(list);
    await NotificationService().scheduleReminder(reminder);

    return reminder;
  }

  Future<Reminder> update(int id, Map<String, dynamic> data) async {
    Reminder updated;
    try {
      final res = await _dio.patch('/api/reminders/$id/', data: data);
      updated = Reminder.fromJson(res.data);
    } catch (_) {
      final list = await getLocalList();
      final idx = list.indexWhere((r) => r.id == id);
      if (idx != -1) {
        final existing = list[idx];
        updated = existing.copyWith(
          title: data['title'] as String?,
          description: data['description'] as String?,
          date: data['date'] as String?,
          time: data['time'] as String?,
          repeat: data['repeat'] as String?,
          isEnabled: data['is_enabled'] as bool?,
          isAlarm: data['is_alarm'] as bool?,
          targetPage: data['target_page'] as String?,
        );
      } else {
        throw Exception('Reminder not found');
      }
    }

    final list = await getLocalList();
    final idx = list.indexWhere((r) => r.id == id);
    if (idx != -1) {
      list[idx] = updated;
    } else {
      list.insert(0, updated);
    }
    await _saveLocal(list);
    await NotificationService().scheduleReminder(updated);

    return updated;
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/api/reminders/$id/');
    } catch (_) {}
    final list = await getLocalList();
    list.removeWhere((r) => r.id == id);
    await _saveLocal(list);
    await NotificationService().cancelNotification(id);
  }

  Future<Reminder> complete(int id) async {
    try {
      final res = await _dio.post('/api/reminders/$id/complete/');
      final rem = Reminder.fromJson(res.data['data'] ?? res.data);
      await NotificationService().cancelNotification(id);
      return rem;
    } catch (_) {
      final list = await getLocalList();
      final idx = list.indexWhere((r) => r.id == id);
      if (idx != -1) {
        final rem = list[idx].copyWith(isCompleted: true);
        list[idx] = rem;
        await _saveLocal(list);
        await NotificationService().cancelNotification(id);
        return rem;
      }
      throw Exception('Reminder not found');
    }
  }

  Future<Reminder> snooze(int id, {int minutes = 5}) async {
    try {
      final res = await _dio.post('/api/reminders/$id/snooze/', data: {'minutes': minutes});
      return Reminder.fromJson(res.data['data'] ?? res.data);
    } catch (_) {
      final list = await getLocalList();
      final idx = list.indexWhere((r) => r.id == id);
      if (idx != -1) {
        final rem = list[idx].copyWith(isSnoozed: true);
        list[idx] = rem;
        await _saveLocal(list);
        return rem;
      }
      throw Exception('Reminder not found');
    }
  }

  Future<List<ReminderHistory>> getHistory(int id) async {
    try {
      final res = await _dio.get('/api/reminders/$id/history/');
      return (readList(res.data)).map((j) => ReminderHistory.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Reminder>> getCalendar({required int year, required int month}) async {
    try {
      final res = await _dio.get('/api/reminders/calendar/', queryParameters: {
        'year': year,
        'month': month,
      });
      return (readList(res.data)).map((j) => Reminder.fromJson(j)).toList();
    } catch (_) {
      return await getLocalList();
    }
  }

  // ── Categories ─────────────────────────────────────────────────
  Future<List<ReminderCategory>> getCategories() async {
    try {
      final res = await _dio.get('/api/reminders/categories/');
      return (readList(res.data)).map((j) => ReminderCategory.fromJson(j)).toList();
    } catch (_) {
      return const [
        ReminderCategory(id: 1, name: 'Prayer', icon: '🙏'),
        ReminderCategory(id: 2, name: 'Bible', icon: '📖'),
        ReminderCategory(id: 3, name: 'Universal Rule', icon: '📜'),
        ReminderCategory(id: 4, name: 'Notes', icon: '📝'),
        ReminderCategory(id: 5, name: 'Devotional', icon: '✨'),
      ];
    }
  }
}
