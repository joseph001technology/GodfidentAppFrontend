import '../core/dio_client.dart';
import '../core/api_response.dart';
import '../models/devotional.dart';

class DevotionalRepository {
  final _dio = DioClient.instance;

  Future<Devotional> getToday() async {
    final res = await _dio.get('/api/devotionals/today/');
    final data = res.data['data'];
    // today endpoint wraps in {date, devotional} or returns devotional directly
    if (data is Map && data.containsKey('devotional')) {
      return Devotional.fromJson(data['devotional']);
    }
    return Devotional.fromJson(data);
  }

  Future<List<Devotional>> getList({String? search, int? category}) async {
    final res = await _dio.get('/api/devotionals/', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (category != null) 'category': category,
    });
    final list = readList(res.data);
    return (list as List).map((j) => Devotional.fromJson(j)).toList();
  }

  Future<Devotional> getDetail(int id) async {
    final res = await _dio.get('/api/devotionals/$id/');
    return Devotional.fromJson(res.data['data'] ?? res.data);
  }

  Future<void> save(int id) async {
    await _dio.post('/api/devotionals/$id/save/');
  }

  Future<void> unsave(int id) async {
    await _dio.delete('/api/devotionals/$id/unsave/');
  }

  Future<List<Devotional>> getSaved() async {
    final res = await _dio.get('/api/devotionals/saved/');
    final list = readList(res.data);
    return (list as List).map((j) => Devotional.fromJson(j)).toList();
  }

  Future<List<DevotionalCategory>> getCategories() async {
    final res = await _dio.get('/api/devotionals/categories/');
    final list = readList(res.data);
    return (list as List).map((j) => DevotionalCategory.fromJson(j)).toList();
  }
}
