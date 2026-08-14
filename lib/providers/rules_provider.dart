import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rule.dart';
import '../repositories/rules_repository.dart';

final rulesRepositoryProvider = Provider((_) => RulesRepository());

// ── Today's Rules (used by the Home screen preview) ───────────────
final todayRulesProvider = FutureProvider<List<Rule>>((ref) {
  return ref.read(rulesRepositoryProvider).getToday();
});

// ── Rule Categories ────────────────────────────────────────────────
final ruleCategoriesProvider = FutureProvider<List<RuleCategory>>((ref) {
  return ref.read(rulesRepositoryProvider).getCategories();
});

// ── All Rules ───────────────────────────────────────────────────────
final rulesProvider = StateNotifierProvider<RulesNotifier, AsyncValue<List<Rule>>>((ref) {
  return RulesNotifier(ref.read(rulesRepositoryProvider));
});

class RulesNotifier extends StateNotifier<AsyncValue<List<Rule>>> {
  final RulesRepository _repo;
  int? _categoryId;

  RulesNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({int? categoryId}) async {
    if (categoryId != null) _categoryId = categoryId;
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getList(categoryId: _categoryId);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => load();

  /// Pass null to clear back to "All categories".
  Future<void> setCategory(int? categoryId) {
    _categoryId = categoryId;
    return load();
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _repo.create(data);
    await refresh();
  }

  Future<void> update(int id, Map<String, dynamic> data) async {
    await _repo.update(id, data);
    await refresh();
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    await refresh();
  }

  /// Toggles today's completion via POST .../toggle_today/ — there is no
  /// writable `is_completed` field to PATCH.
  Future<void> toggleToday(int id) async {
    await _repo.toggleToday(id);
    await refresh();
  }

  Future<void> togglePin(int id) async {
    await _repo.togglePin(id);
    await refresh();
  }

  Future<void> toggleFavorite(int id) async {
    await _repo.toggleFavorite(id);
    await refresh();
  }

  Future<void> reorder(List<int> orderedIds) async {
    await _repo.reorderRules(orderedIds);
    await refresh();
  }
}