import '../core/dio_client.dart';
import '../core/api_response.dart';
import '../models/rule.dart';

class RulesRepository {
  final _dio = DioClient.instance;

  Future<List<Rule>> getToday() async {
    final res = await _dio.get('/api/rules/today/');
    return (readList(res.data)).map((j) => Rule.fromJson(j)).toList();
  }

  Future<List<Rule>> getList({
    int? category,
    bool? archived,
    String? search,
    String ordering = 'order',
  }) async {
    final res = await _dio.get('/api/rules/', queryParameters: {
      if (category != null) 'category': category,
      if (archived != null) 'is_archived': archived,
      if (search != null) 'search': search,
      'ordering': ordering,
    });
    return (readList(res.data)).map((j) => Rule.fromJson(j)).toList();
  }

  Future<Rule> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/rules/', data: data);
    return Rule.fromJson(res.data);
  }

  Future<Rule> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/rules/$id/', data: data);
    return Rule.fromJson(res.data['data'] ?? res.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/api/rules/$id/');
  }

  Future<Rule> togglePin(int id) async {
    final res = await _dio.post('/api/rules/$id/toggle_pin/');
    return Rule.fromJson(res.data['data'] ?? res.data);
  }

  Future<Rule> toggleFavorite(int id) async {
    final res = await _dio.post('/api/rules/$id/toggle_favorite/');
    return Rule.fromJson(res.data['data'] ?? res.data);
  }

  Future<void> archive(int id) async {
    await _dio.post('/api/rules/$id/archive/');
  }

  Future<void> reorder(int id, int newOrder) async {
    await _dio.post('/api/rules/$id/reorder/', data: {'order': newOrder});
  }

  // ── Categories ─────────────────────────────────────────────────
  Future<List<RuleCategory>> getCategories() async {
    final res = await _dio.get('/api/rules/categories/');
    return (readList(res.data)).map((j) => RuleCategory.fromJson(j)).toList();
  }
}
