import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reminder.dart';
import '../repositories/reminders_repository.dart';
import '../services/notification_service.dart';
import '../services/ringtone_store.dart';

final remindersRepositoryProvider = Provider((_) => RemindersRepository());

final remindersProvider = StateNotifierProvider<RemindersNotifier, AsyncValue<List<Reminder>>>((ref) {
  return RemindersNotifier(ref.read(remindersRepositoryProvider), NotificationService());
});

/// Owns reminder state AND is the single place that schedules the phone's
/// notifications. Scheduling problems never break saving, and every change is
/// reflected on screen immediately (optimistic) before the network finishes.
class RemindersNotifier extends StateNotifier<AsyncValue<List<Reminder>>> {
  final RemindersRepository _repo;
  final NotificationService _notif;
  String? _date;
  int? _categoryId;
  bool? _completed;
  bool _loading = false;

  RemindersNotifier(this._repo, this._notif) : super(const AsyncValue.loading()) {
    load();
  }

  List<Reminder> get _current => state.valueOrNull ?? const [];

  Future<void> load({String? date, int? category, bool? completed}) async {
    if (_loading) return;
    _loading = true;
    if (date != null) _date = date;
    if (category != null) _categoryId = category;
    if (completed != null) _completed = completed;
    // Only show the spinner the very first time; later refreshes are silent.
    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      final list = await _repo.getList(date: _date, category: _categoryId, completed: _completed);
      if (mounted) state = AsyncValue.data(list);
      await _rescheduleForList(list);
    } catch (e, st) {
      if (mounted && !state.hasValue) state = AsyncValue.error(e, st);
    } finally {
      _loading = false;
    }
  }

  Future<void> _rescheduleForList(List<Reminder> list) async {
    for (final r in list) {
      if (r.isActive) {
        await _notif.scheduleReminder(r);
      } else {
        await _notif.cancelReminder(r.id);
      }
    }
  }

  Future<void> refresh() => load();

  /// Throws only if the SERVER rejects the data, so the editor can show why.
  Future<Reminder> create(Map<String, dynamic> data, {Ringtone? ringtone}) async {
    final created = await _repo.create(data);
    if (ringtone != null) await RingtoneStore.instance.save(created.id, ringtone);
    await _notif.scheduleReminder(created);
    state = AsyncValue.data([created, ..._current.where((r) => r.id != created.id)]);
    load();
    return created;
  }

  Future<void> update(int id, Map<String, dynamic> data, {Ringtone? ringtone}) async {
    final updated = await _repo.update(id, data);
    if (ringtone != null) await RingtoneStore.instance.save(id, ringtone);
    await _notif.cancelReminder(id);
    await _notif.scheduleReminder(updated);
    state = AsyncValue.data([for (final r in _current) r.id == id ? updated : r]);
    load();
  }

  /// Removes the card from the list FIRST (synchronously) - a swiped
  /// Dismissible must leave the widget tree in the same frame or Flutter
  /// throws and the screen goes black.
  Future<void> delete(int id) async {
    state = AsyncValue.data(_current.where((r) => r.id != id).toList());
    await _notif.cancelReminder(id);
    try {
      await _repo.delete(id);
    } catch (_) {
      // Remembered for retry in the repository; the card stays removed.
    }
  }

  Future<void> complete(int id) async {
    await _notif.cancelReminder(id);
    try {
      final done = await _repo.complete(id);
      state = AsyncValue.data([for (final r in _current) r.id == id ? done : r]);
    } finally {
      load();
    }
  }

  Future<void> snooze(int id, {int minutes = 5}) async {
    final rem = await _repo.snooze(id, minutes: minutes);
    await _notif.scheduleReminder(rem);
    load();
  }

  Future<void> toggleEnabled(int id) async {
    final idx = _current.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final updated = _current[idx].copyWith(isEnabled: !_current[idx].isEnabled);
    state = AsyncValue.data([for (final r in _current) r.id == id ? updated : r]);
    if (updated.isActive) {
      await _notif.scheduleReminder(updated);
    } else {
      await _notif.cancelReminder(id);
    }
    try {
      await _repo.update(id, {'is_enabled': updated.isEnabled});
    } catch (_) {
      load(); // server said no: show the truth
    }
  }
}

final reminderCategoriesProvider = FutureProvider<List<ReminderCategory>>((ref) {
  return ref.read(remindersRepositoryProvider).getCategories();
});

final calendarRemindersProvider = FutureProvider.family<List<Reminder>, DateTime>((ref, date) {
  return ref.read(remindersRepositoryProvider).getCalendar(year: date.year, month: date.month);
});

final reminderHistoryProvider = FutureProvider.family<List<ReminderHistory>, int>((ref, id) {
  return ref.read(remindersRepositoryProvider).getHistory(id);
});
