import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rule.dart';
import '../repositories/rules_repository.dart';

final rulesRepositoryProvider = Provider((_) => RulesRepository());

// ── Today's Rules ────────────────────────────────────────────────
final todayRulesProvider = FutureProvider<List<Rule>>((ref) {
  return ref.read(rulesRepositoryProvider).getToday();
});

// ── All Rules ────────────────────────────────────────────────────
final rulesProvider = StateNotifierProvider<RulesNotifier, AsyncValue<List<Rule>>>((ref) {
  return RulesNotifier(ref.read(rulesRepositoryProvider));
});

class RulesNotifier extends StateNotifier<AsyncValue<List<Rule>>> {
  final RulesRepository _repo;
  int? _categoryId;

  RulesNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({int? category}) async {
    if (category != null) _categoryId = category;
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getList(category: _categoryId);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => load();

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

  Future<void> toggleComplete(int id, bool completed) async {
    await _repo.update(id, {'is_completed': completed});
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
}

final ruleCategoriesProvider = FutureProvider<List<RuleCategory>>((ref) {
  return ref.read(rulesRepositoryProvider).getCategories();
});
