import '../core/dio_client.dart';
import '../core/api_response.dart';
import '../models/prayer.dart';

class PrayerRepository {
  final _dio = DioClient.instance;

  Future<List<Prayer>> getList({
    String? prayerType,
    String? status,
    String? search,
    String ordering = '-created_at',
  }) async {
    final res = await _dio.get('/api/prayer/', queryParameters: {
      if (prayerType != null) 'prayer_type': prayerType,
      if (status != null) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      'ordering': ordering,
    });
    final list = readList(res.data);
    return (list).map((j) => Prayer.fromJson(j)).toList();
  }

  Future<List<PrayerCategory>> getCategories() async {
    final res = await _dio.get('/api/prayer/categories/');
    return readList(res.data).map((j) => PrayerCategory.fromJson(j)).toList();
  }

  Future<Prayer> getDetail(int id) async {
    final res = await _dio.get('/api/prayer/$id/');
    return Prayer.fromJson(readMap(res.data));
  }

  Future<Prayer> create({
    required String title,
    required String content,
    String prayerType = 'request',
    String scripture = '',
    int? category,
    bool reminderEnabled = false,
    bool isPrivate = true,
  }) async {
    final res = await _dio.post('/api/prayer/', data: {
      'title': title,
      'content': content,
      'prayer_type': prayerType,
      if (scripture.isNotEmpty) 'scripture': scripture,
      if (category != null) 'category': category,
      'reminder_enabled': reminderEnabled,
      'is_private': isPrivate,
    });
    return Prayer.fromJson(res.data);
  }

  Future<Prayer> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/prayer/$id/', data: data);
    return Prayer.fromJson(readMap(res.data));
  }

  Future<void> delete(int id) async {
    await _dio.delete('/api/prayer/$id/');
  }

  Future<void> markAnswered(int id, {String note = ''}) async {
    await _dio.post('/api/prayer/$id/mark_answered/', data: {
      if (note.isNotEmpty) 'note': note,
    });
  }

  Future<void> logPrayer(int id, {String note = ''}) async {
    await _dio.post('/api/prayer/$id/log_prayer/', data: {
      if (note.isNotEmpty) 'note': note,
    });
  }

  /// Alias for logPrayer - records that a prayer was prayed
  Future<void> recordPrayer(int id, {String note = ''}) => logPrayer(id, note: note);

  Future<PrayerStats> getStats() async {
    final res = await _dio.get('/api/prayer/stats/');
    return PrayerStats.fromJson(readDataMap(res.data));
  }

  // ── Prayer Sessions (/api/prayer/sessions/) ─────────────────────
  Future<List<PrayerSession>> getSessions() async {
    final res = await _dio.get('/api/prayer/sessions/');
    return (readList(res.data)).map((j) => PrayerSession.fromJson(j)).toList();
  }

  Future<PrayerSession> createSession({String title = '', String notes = ''}) async {
    final res = await _dio.post('/api/prayer/sessions/', data: {
      if (title.isNotEmpty) 'title': title,
      if (notes.isNotEmpty) 'notes': notes,
    });
    return PrayerSession.fromJson(readMap(res.data));
  }

  Future<PrayerSession> endSession(int id, {required int durationSeconds}) async {
    final res = await _dio.post('/api/prayer/sessions/$id/end/', data: {
      'duration_seconds': durationSeconds,
    });
    return PrayerSession.fromJson(readDataMap(res.data));
  }

  Future<void> deleteSession(int id) async {
    await _dio.delete('/api/prayer/sessions/$id/');
  }

  // ── Prayer Logs (/api/prayer/logs/) ─────────────────────────────
  Future<List<PrayerLog>> getLogs() async {
    final res = await _dio.get('/api/prayer/logs/');
    return (readList(res.data)).map((j) => PrayerLog.fromJson(j)).toList();
  }

  Future<PrayerLog> createLog({required int prayerId, String note = ''}) async {
    final res = await _dio.post('/api/prayer/logs/', data: {
      'prayer': prayerId,
      if (note.isNotEmpty) 'note': note,
    });
    return PrayerLog.fromJson(readMap(res.data));
  }

  Future<void> deleteLog(int id) async {
    await _dio.delete('/api/prayer/logs/$id/');
  }

  // ── Prayer Timer Logs (/api/prayer/timer-logs/) ─────────────────
  Future<List<PrayerTimerLog>> getTimerLogs() async {
    final res = await _dio.get('/api/prayer/timer-logs/');
    return (readList(res.data)).map((j) => PrayerTimerLog.fromJson(j)).toList();
  }

  Future<PrayerTimerLog> createTimerLog({required int durationSeconds}) async {
    final res = await _dio.post('/api/prayer/timer-logs/', data: {
      'duration_seconds': durationSeconds,
    });
    return PrayerTimerLog.fromJson(readMap(res.data));
  }

  Future<void> deleteTimerLog(int id) async {
    await _dio.delete('/api/prayer/timer-logs/$id/');
  }

  // ── Prayer Journal (/api/prayer/journals/) ──────────────────────
  Future<List<PrayerJournal>> getJournals() async {
    final res = await _dio.get('/api/prayer/journals/');
    return (readList(res.data)).map((j) => PrayerJournal.fromJson(j)).toList();
  }

  Future<PrayerJournal> createJournal(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/prayer/journals/', data: data);
    return PrayerJournal.fromJson(readMap(res.data));
  }

  Future<PrayerJournal> updateJournal(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/prayer/journals/$id/', data: data);
    return PrayerJournal.fromJson(readMap(res.data));
  }

  Future<void> deleteJournal(int id) async {
    await _dio.delete('/api/prayer/journals/$id/');
  }
}
