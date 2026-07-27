import '../core/dio_client.dart';
import '../core/api_response.dart';
import '../models/reminder.dart';

class RemindersRepository {
  final _dio = DioClient.instance;

  Future<List<Reminder>> getList({
    String? date,
    int? category,
    bool? completed,
    String? search,
    String ordering = 'date,time',
  }) async {
    final res = await _dio.get('/api/reminders/', queryParameters: {
      if (date != null) 'date': date,
      if (category != null) 'category': category,
      if (completed != null) 'is_completed': completed,
      if (search != null) 'search': search,
      'ordering': ordering,
    });
    return (readList(res.data) as List).map((j) => Reminder.fromJson(j)).toList();
  }

  Future<Reminder> getDetail(int id) async {
    final res = await _dio.get('/api/reminders/$id/');
    return Reminder.fromJson(res.data['data'] ?? res.data);
  }

  Future<Reminder> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/reminders/', data: data);
    return Reminder.fromJson(res.data);
  }

  Future<Reminder> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/reminders/$id/', data: data);
    return Reminder.fromJson(res.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/api/reminders/$id/');
  }

  Future<Reminder> complete(int id) async {
    final res = await _dio.post('/api/reminders/$id/complete/');
    return Reminder.fromJson(res.data['data'] ?? res.data);
  }

  Future<Reminder> snooze(int id, {int minutes = 5}) async {
    final res = await _dio.post('/api/reminders/$id/snooze/', data: {
      'minutes': minutes,
    });
    return Reminder.fromJson(res.data['data'] ?? res.data);
  }

  Future<List<ReminderHistory>> getHistory(int id) async {
    final res = await _dio.get('/api/reminders/$id/history/');
    return (readList(res.data) as List).map((j) => ReminderHistory.fromJson(j)).toList();
  }

  Future<List<Reminder>> getCalendar({required int year, required int month}) async {
    final res = await _dio.get('/api/reminders/calendar/', queryParameters: {
      'year': year,
      'month': month,
    });
    return (readList(res.data) as List).map((j) => Reminder.fromJson(j)).toList();
  }

  // ── Categories ─────────────────────────────────────────────────
  Future<List<ReminderCategory>> getCategories() async {
    final res = await _dio.get('/api/reminders/categories/');
    return (readList(res.data) as List).map((j) => ReminderCategory.fromJson(j)).toList();
  }
}
