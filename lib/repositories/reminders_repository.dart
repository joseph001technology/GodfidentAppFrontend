import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/dio_client.dart';
import '../core/api_response.dart';
import '../models/reminder.dart';
import '../services/notification_service.dart';
import '../services/ringtone_store.dart';

/// Reminders live on the server, with a copy on the phone so they still work
/// offline. This class never schedules notifications itself - that is done in
/// ONE place (RemindersNotifier) so a reminder can never fire twice.
class RemindersRepository {
  final _dio = DioClient.instance;
  static const _localKey = 'godfident_offline_reminders';
  static const _pendingDeleteKey = 'godfident_pending_reminder_deletes';

  /// True when the failure is "no connection" (safe to keep working offline),
  /// as opposed to the server rejecting the data (which the user must see).
  static bool isOffline(Object e) {
    if (e is! DioException) return false;
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        (e.type == DioExceptionType.unknown && e.response == null);
  }

  // ── Reading ────────────────────────────────────────────────────
  Future<List<Reminder>> getList({
    String? date,
    int? category,
    bool? completed,
    String? search,
    String ordering = 'date,time',
  }) async {
    try {
      await _pushPending();
      final res = await _dio.get('/api/reminders/', queryParameters: {
        if (date != null) 'date': date,
        if (category != null) 'category': category,
        if (completed != null) 'is_completed': completed,
        if (search != null) 'search': search,
        'ordering': ordering,
      });
      final list = readList(res.data).map((j) => Reminder.fromJson(j)).toList();
      await _saveLocal(list);
      return list;
    } catch (e) {
      if (isOffline(e)) return getLocalList(); // honest offline copy
      rethrow;
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
    await prefs.setString(_localKey, jsonEncode(list.map((r) => r.toJson()).toList()));
  }

  Future<Reminder> getDetail(int id) async {
    try {
      final res = await _dio.get('/api/reminders/$id/');
      return Reminder.fromJson(res.data['data'] ?? res.data);
    } catch (e) {
      if (!isOffline(e)) rethrow;
      final list = await getLocalList();
      return list.firstWhere((r) => r.id == id, orElse: () => throw Exception('Reminder not found'));
    }
  }

  // ── Writing ────────────────────────────────────────────────────
  /// Server errors (bad data, expired login) are thrown so the user sees them.
  /// Only a real lack of connection creates a phone-only reminder (negative id)
  /// that is uploaded automatically the next time the app is online.
  Future<Reminder> create(Map<String, dynamic> data) async {
    Reminder reminder;
    try {
      final res = await _dio.post('/api/reminders/', data: data);
      reminder = Reminder.fromJson(Map<String, dynamic>.from(res.data['data'] ?? res.data));
    } catch (e) {
      if (!isOffline(e)) rethrow;
      reminder = Reminder(
        id: -(DateTime.now().millisecondsSinceEpoch % 100000000) - 1,
        title: data['title'] ?? 'Reminder',
        description: data['description'],
        date: data['date'] ?? DateTime.now().toIso8601String().split('T').first,
        time: data['time'] ?? '08:00:00',
        repeat: data['repeat'] ?? 'none',
        isEnabled: data['is_enabled'] ?? true,
        isAlarm: data['is_alarm'] ?? false,
        targetPage: data['target_page'] ?? 'general',
        createdAt: DateTime.now().toIso8601String(),
      );
    }
    final list = await getLocalList();
    list.removeWhere((r) => r.id == reminder.id);
    list.insert(0, reminder);
    await _saveLocal(list);
    return reminder;
  }

  Future<Reminder> update(int id, Map<String, dynamic> data) async {
    Reminder updated;
    try {
      if (id < 0) throw DioException.connectionError(requestOptions: RequestOptions(path: ''), reason: 'pending');
      final res = await _dio.patch('/api/reminders/$id/', data: data);
      updated = Reminder.fromJson(Map<String, dynamic>.from(res.data['data'] ?? res.data));
    } catch (e) {
      if (!isOffline(e)) rethrow;
      final list = await getLocalList();
      final idx = list.indexWhere((r) => r.id == id);
      if (idx == -1) throw Exception('Reminder not found');
      updated = list[idx].copyWith(
        title: data['title'] as String?,
        description: data['description'] as String?,
        date: data['date'] as String?,
        time: data['time'] as String?,
        repeat: data['repeat'] as String?,
        isEnabled: data['is_enabled'] as bool?,
        isAlarm: data['is_alarm'] as bool?,
        targetPage: data['target_page'] as String?,
      );
    }
    final list = await getLocalList();
    final idx = list.indexWhere((r) => r.id == id);
    if (idx != -1) {
      list[idx] = updated;
    } else {
      list.insert(0, updated);
    }
    await _saveLocal(list);
    return updated;
  }

  /// The local copy is changed first (the caller already removed it from the
  /// screen). If the server can't be reached the delete is remembered and
  /// retried, so the reminder doesn't come back.
  Future<void> delete(int id) async {
    final list = await getLocalList();
    list.removeWhere((r) => r.id == id);
    await _saveLocal(list);
    await RingtoneStore.instance.remove(id);
    if (id < 0) return; // never reached the server
    try {
      await _dio.delete('/api/reminders/$id/');
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) return;
      final p = await SharedPreferences.getInstance();
      final pending = p.getStringList(_pendingDeleteKey) ?? [];
      if (!pending.contains('$id')) pending.add('$id');
      await p.setStringList(_pendingDeleteKey, pending);
      if (!isOffline(e)) rethrow;
    }
  }

  Future<void> _pushPending() async {
    final p = await SharedPreferences.getInstance();

    // 1. Retry deletes that couldn't reach the server.
    final pending = List<String>.from(p.getStringList(_pendingDeleteKey) ?? []);
    for (final id in pending.toList()) {
      try {
        await _dio.delete('/api/reminders/$id/');
        pending.remove(id);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) pending.remove(id);
      }
    }
    await p.setStringList(_pendingDeleteKey, pending);

    // 2. Upload reminders created while offline.
    final local = await getLocalList();
    var changed = false;
    for (var i = 0; i < local.length; i++) {
      final r = local[i];
      if (r.id >= 0) continue;
      try {
        final res = await _dio.post('/api/reminders/', data: {
          'title': r.title,
          if (r.description != null) 'description': r.description,
          'date': r.date,
          if (r.time != null) 'time': r.time,
          'repeat': r.repeat,
          'is_alarm': r.isAlarm,
        });
        final saved = Reminder.fromJson(Map<String, dynamic>.from(res.data['data'] ?? res.data));
        await NotificationService().cancelReminder(r.id);
        await RingtoneStore.instance.move(r.id, saved.id);
        local[i] = saved;
        changed = true;
      } on DioException catch (_) {
        // still offline or rejected - keep it on the phone
      }
    }
    if (changed) await _saveLocal(local);
  }

  Future<Reminder> complete(int id) async {
    try {
      final res = await _dio.post('/api/reminders/$id/complete/');
      return Reminder.fromJson(Map<String, dynamic>.from(res.data['data'] ?? res.data));
    } catch (e) {
      if (!isOffline(e)) rethrow;
      final list = await getLocalList();
      final idx = list.indexWhere((r) => r.id == id);
      if (idx == -1) throw Exception('Reminder not found');
      final rem = list[idx].copyWith(isCompleted: true);
      list[idx] = rem;
      await _saveLocal(list);
      return rem;
    }
  }

  Future<Reminder> snooze(int id, {int minutes = 5}) async {
    try {
      final res = await _dio.post('/api/reminders/$id/snooze/', data: {'minutes': minutes});
      return Reminder.fromJson(Map<String, dynamic>.from(res.data['data'] ?? res.data));
    } catch (e) {
      if (!isOffline(e)) rethrow;
      final list = await getLocalList();
      final idx = list.indexWhere((r) => r.id == id);
      if (idx == -1) throw Exception('Reminder not found');
      final rem = list[idx].copyWith(isSnoozed: true);
      list[idx] = rem;
      await _saveLocal(list);
      return rem;
    }
  }

  Future<List<ReminderHistory>> getHistory(int id) async {
    final res = await _dio.get('/api/reminders/$id/history/');
    return readList(res.data).map((j) => ReminderHistory.fromJson(j)).toList();
  }

  Future<List<Reminder>> getCalendar({required int year, required int month}) async {
    try {
      final res = await _dio.get('/api/reminders/calendar/', queryParameters: {'year': year, 'month': month});
      return readList(res.data).map((j) => Reminder.fromJson(j)).toList();
    } catch (e) {
      if (isOffline(e)) return getLocalList();
      rethrow;
    }
  }

  // ── Categories (from the server only - no invented fallback) ───
  Future<List<ReminderCategory>> getCategories() async {
    final res = await _dio.get('/api/reminders/categories/');
    return readList(res.data).map((j) => ReminderCategory.fromJson(j)).toList();
  }
}
