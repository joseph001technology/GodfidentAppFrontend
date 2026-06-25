import '../core/dio_client.dart';
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
    final list = res.data['results'] ?? res.data;
    return (list as List).map((j) => Prayer.fromJson(j)).toList();
  }

  Future<Prayer> create({
    required String title,
    required String content,
    String prayerType = 'request',
    String scripture = '',
    bool isPrivate = true,
  }) async {
    final res = await _dio.post('/api/prayer/', data: {
      'title': title,
      'content': content,
      'prayer_type': prayerType,
      if (scripture.isNotEmpty) 'scripture': scripture,
      'is_private': isPrivate,
    });
    return Prayer.fromJson(res.data);
  }

  Future<Prayer> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/prayer/$id/', data: data);
    return Prayer.fromJson(res.data);
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

  Future<PrayerStats> getStats() async {
    final res = await _dio.get('/api/prayer/stats/');
    return PrayerStats.fromJson(res.data['data']);
  }
}
