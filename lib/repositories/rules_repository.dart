import '../core/dio_client.dart';
import '../core/api_response.dart';
import '../models/rule.dart';

class RulesRepository {
  final _dio = DioClient.instance;

  Future<List<Rule>> getToday() async {
    final res = await _dio.get('/api/rules/today/');
    return readList(res.data).map((j) => Rule.fromJson(readMap(j))).toList();
  }

  // 'category' and 'is_archived' work here via RuleViewSet's automatic
  // DjangoFilterBackend (filterset_fields = ['category', 'is_archived']) —
  // unlike Notes, which has no filter backend wired up and needs its own
  // manually-read param names instead.
  Future<List<Rule>> getList({
    int? categoryId,
    bool? archived,
    bool? pinned,
    bool? favorite,
    String? search,
    String ordering = 'order',
  }) async {
    final res = await _dio.get('/api/rules/', queryParameters: {
      if (categoryId != null) 'category': categoryId,
      if (archived != null) 'is_archived': archived,
      if (pinned != null) 'pinned': pinned,
      if (favorite != null) 'favorite': favorite,
      if (search != null) 'search': search,
      'ordering': ordering,
    });
    return readList(res.data).map((j) => Rule.fromJson(readMap(j))).toList();
  }

  Future<Rule> getById(int id) async {
    final res = await _dio.get('/api/rules/$id/');
    return Rule.fromJson(readDataMap(res.data));
  }

  Future<Rule> create(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/rules/', data: data);
    return Rule.fromJson(readDataMap(res.data));
  }

  Future<Rule> update(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/rules/$id/', data: data);
    return Rule.fromJson(readDataMap(res.data));
  }

  Future<void> delete(int id) async {
    await _dio.delete('/api/rules/$id/');
  }

  /// POST /rules/{id}/toggle_today/ — completion is a daily RuleCompletion
  /// record, not a plain field on Rule, so it needs its own endpoint rather
  /// than a PATCH with `is_completed` (which the old code tried — that key
  /// doesn't exist as a writable field on the backend and silently no-ops).
  Future<bool> toggleToday(int id) async {
    final res = await _dio.post('/api/rules/$id/toggle_today/');
    return readMap(res.data)['is_completed'] == true;
  }

  Future<bool> togglePin(int id) async {
    final res = await _dio.post('/api/rules/$id/toggle_pin/');
    return readMap(res.data)['is_pinned'] == true;
  }

  Future<bool> toggleFavorite(int id) async {
    final res = await _dio.post('/api/rules/$id/toggle_favorite/');
    return readMap(res.data)['is_favorite'] == true;
  }

  Future<void> archive(int id) async {
    await _dio.post('/api/rules/$id/archive/');
  }

  Future<void> restore(int id) async {
    await _dio.post('/api/rules/$id/restore/');
  }

  /// Bulk reorder. Replaces the old `POST /rules/{id}/reorder/` endpoint,
  /// which no longer exists — the backend now takes the whole ordered list
  /// at once via `POST /rules/reorder/`.
  Future<void> reorderRules(List<int> orderedIds) async {
    await _dio.post('/api/rules/reorder/', data: {'ordered_ids': orderedIds});
  }

  // ── Categories ─────────────────────────────────────────────────
  Future<List<RuleCategory>> getCategories() async {
    final res = await _dio.get('/api/rules/categories/');
    return readList(res.data).map((j) => RuleCategory.fromJson(readMap(j))).toList();
  }

  Future<RuleCategory> createCategory(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/rules/categories/', data: data);
    return RuleCategory.fromJson(readDataMap(res.data));
  }

  Future<void> reorderCategories(List<int> orderedIds) async {
    await _dio.post('/api/rules/categories/reorder/', data: {'ordered_ids': orderedIds});
  }
}