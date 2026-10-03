import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/focus.dart';
import '../repositories/focus_repository.dart';

final focusRepositoryProvider = Provider((_) => FocusRepository());

// ── Focus Session ────────────────────────────────────────────────
final activeSessionProvider = StateNotifierProvider<ActiveSessionNotifier, AsyncValue<FocusSession?>>((ref) {
  return ActiveSessionNotifier(ref.read(focusRepositoryProvider));
});

class ActiveSessionNotifier extends StateNotifier<AsyncValue<FocusSession?>> {
  final FocusRepository _repo;
  ActiveSessionNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<void> start() async {
    state = const AsyncValue.loading();
    try {
      final session = await _repo.startSession();
      state = AsyncValue.data(session);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> end({int? durationMinutes, int? focusScore}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = const AsyncValue.loading();
    try {
      final ended = await _repo.endSession(current.id, durationMinutes: durationMinutes, focusScore: focusScore);
      state = AsyncValue.data(ended);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ── Blocked Apps ─────────────────────────────────────────────────
final blockedAppsProvider = FutureProvider<List<BlockedApp>>((ref) {
  return ref.read(focusRepositoryProvider).getBlockedApps();
});

final blockedWebsitesProvider = FutureProvider<List<BlockedWebsite>>((ref) {
  return ref.read(focusRepositoryProvider).getBlockedWebsites();
});

// ── Whitelist ────────────────────────────────────────────────────
final whitelistAppsProvider = FutureProvider<List<WhitelistApp>>((ref) {
  return ref.read(focusRepositoryProvider).getWhitelistApps();
});

// ── Schedules ────────────────────────────────────────────────────
final focusSchedulesProvider = FutureProvider<List<FocusSchedule>>((ref) {
  return ref.read(focusRepositoryProvider).getSchedules();
});

// ── Blocked Attempts ─────────────────────────────────────────────
final blockedAttemptsProvider = FutureProvider<List<BlockedAttempt>>((ref) {
  return ref.read(focusRepositoryProvider).getBlockedAttempts(limit: 10);
});

// ── Stats ────────────────────────────────────────────────────────
final focusStatsProvider = FutureProvider<FocusStats>((ref) {
  return ref.read(focusRepositoryProvider).getStats();
});
