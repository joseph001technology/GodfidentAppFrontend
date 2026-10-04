import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scheduled_focus.dart';
import '../services/notification_service.dart';
import '../services/ringtone_store.dart';
import '../services/scheduled_focus_store.dart';

final scheduledFocusProvider =
    StateNotifierProvider<ScheduledFocusNotifier, AsyncValue<List<ScheduledFocus>>>((ref) => ScheduledFocusNotifier());

/// Pre-set Focus sessions. The phone copy is saved first and the alarms are
/// armed from it, so everything works offline; the account copy follows.
class ScheduledFocusNotifier extends StateNotifier<AsyncValue<List<ScheduledFocus>>> {
  ScheduledFocusNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  final _store = ScheduledFocusStore.instance;
  final _notif = NotificationService();

  Future<void> load() async {
    var list = await _store.load();
    if (mounted) state = AsyncValue.data(list);
    if (await _store.sync()) {
      final fresh = await _store.load();
      if (fresh.length != list.length) {
        // Restored from the account: arm the alarms for them.
        for (final f in fresh) {
          await _notif.scheduleFocusSession(f);
        }
      }
      list = fresh;
      if (mounted) state = AsyncValue.data(list);
    }
  }

  /// Creates a new id on the phone (use before saving a new session).
  Future<int> newId() => _store.newId();

  Future<ScheduledFocus?> byId(int id) async {
    final list = await _store.load();
    for (final f in list) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Saves (add or edit) and arms/cancels the alarm. Returns false only when
  /// Android refused to schedule the alarm.
  Future<bool> save(ScheduledFocus f, {Ringtone? ringtone}) async {
    if (ringtone != null) {
      // Key is separate from reminder ids; do not overwrite the default tone of reminders.
      await RingtoneStore.instance.saveFor(NotificationService.focusRingtoneKey(f.id), ringtone);
    }
    final saved = await _store.upsert(f);
    final ok = await _notif.scheduleFocusSession(saved);
    state = AsyncValue.data(await _store.load());
    _store.sync().then((done) async {
      if (done && mounted) state = AsyncValue.data(await _store.load());
    });
    return ok;
  }

  Future<void> toggle(ScheduledFocus f, bool on) async {
    await save(f.copyWith(enabled: on));
  }

  Future<void> delete(int id) async {
    await _notif.cancelFocusSession(id);
    await RingtoneStore.instance.remove(NotificationService.focusRingtoneKey(id));
    await _store.remove(id);
    state = AsyncValue.data(await _store.load());
    _store.sync();
  }

  /// Stops the ringing after Start; one-time sessions switch themselves off.
  Future<void> started(ScheduledFocus f) async {
    if (f.days.isEmpty) {
      await _notif.cancelFocusSession(f.id);
      await save(f.copyWith(enabled: false));
    } else {
      await _notif.silenceFocusRing(f);
    }
  }
}
