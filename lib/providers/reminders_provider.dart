import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reminder.dart';
import '../repositories/reminders_repository.dart';

final remindersRepositoryProvider = Provider((_) => RemindersRepository());

// ── Reminders ────────────────────────────────────────────────────
final remindersProvider = StateNotifierProvider<RemindersNotifier, AsyncValue<List<Reminder>>>((ref) {
  return RemindersNotifier(ref.read(remindersRepositoryProvider));
});

class RemindersNotifier extends StateNotifier<AsyncValue<List<Reminder>>> {
  final RemindersRepository _repo;
  String? _date;
  int? _categoryId;
  bool? _completed;

  RemindersNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({String? date, int? category, bool? completed}) async {
    if (date != null) _date = date;
    if (category != null) _categoryId = category;
    if (completed != null) _completed = completed;
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getList(date: _date, category: _categoryId, completed: _completed);
      state = AsyncValue.data(list);
    } catch (e, st) {
      // Fallback to offline data
      try {
        final local = await _repo.getLocalList();
        state = AsyncValue.data(local);
      } catch (e2, st2) {
        state = AsyncValue.error(e2, st2);
      }
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

  Future<void> complete(int id) async {
    await _repo.complete(id);
    await refresh();
  }

  Future<void> snooze(int id, {int minutes = 5}) async {
    await _repo.snooze(id, minutes: minutes);
    await refresh();
  }

  Future<void> toggleEnabled(int id) async {
    final current = state.value;
    if (current == null) return;
    final idx = current.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final reminder = current[idx];
    final updated = reminder.copyWith(isEnabled: !reminder.isEnabled);
    // Optimistically update state
    final newList = List<Reminder>.from(current);
    newList[idx] = updated;
    state = AsyncValue.data(newList);
    await _repo.update(id, {'is_enabled': updated.isEnabled});
  }
}

final reminderCategoriesProvider = FutureProvider<List<ReminderCategory>>((ref) {
  return ref.read(remindersRepositoryProvider).getCategories();
});

final calendarRemindersProvider = FutureProvider.family<List<Reminder>, DateTime>((ref, date) {
  return ref.read(remindersRepositoryProvider).getCalendar(year: date.year, month: date.month);
});

/// History for a single reminder (family keyed by reminder id).
final reminderHistoryProvider =
    FutureProvider.family<List<ReminderHistory>, int>((ref, id) {
  return ref.read(remindersRepositoryProvider).getHistory(id);
});
