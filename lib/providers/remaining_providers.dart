import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/devotional.dart';
import '../models/prayer.dart';
import '../models/reading_plan.dart';
import '../models/chat_message.dart';
import '../models/notification.dart';
import '../models/analytics.dart';
import '../models/note.dart';
import '../models/universal_rule.dart';
import '../models/reminder.dart';
import '../repositories/devotional_repository.dart';
import '../repositories/prayer_repository.dart';
import '../repositories/reading_plan_repository.dart';
import '../repositories/ai_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/notes_repository.dart';
import '../repositories/universal_rules_repository.dart';
import '../repositories/reminders_repository.dart';

// ── Repositories ──────────────────────────────────────────────────────────────

final devotionalRepositoryProvider = Provider((_) => DevotionalRepository());
final prayerRepositoryProvider     = Provider((_) => PrayerRepository());
final planRepositoryProvider       = Provider((_) => ReadingPlanRepository());
final aiRepositoryProvider         = Provider((_) => AiRepository());
final notificationRepositoryProvider = Provider((_) => NotificationRepository());
final analyticsRepositoryProvider  = Provider((_) => AnalyticsRepository());
final notesRepositoryProvider      = Provider((_) => LocalNotesRepository());
final rulesRepositoryProvider      = Provider((_) => LocalUniversalRulesRepository());
final remindersRepositoryProvider  = Provider((_) => LocalRemindersRepository());

// ── Devotionals ───────────────────────────────────────────────────────────────

final todayDevotionalProvider = FutureProvider<Devotional>((ref) {
  return ref.read(devotionalRepositoryProvider).getToday();
});

final devotionalListProvider = FutureProvider<List<Devotional>>((ref) {
  return ref.read(devotionalRepositoryProvider).getList();
});

final savedDevotionalsProvider = FutureProvider<List<Devotional>>((ref) {
  return ref.read(devotionalRepositoryProvider).getSaved();
});

final devotionalCategoriesProvider = FutureProvider<List<DevotionalCategory>>((ref) {
  return ref.read(devotionalRepositoryProvider).getCategories();
});

final selectedDevotionalCategoryProvider = StateProvider<int?>((ref) => null);

final filteredDevotionalListProvider = FutureProvider<List<Devotional>>((ref) {
  final category = ref.watch(selectedDevotionalCategoryProvider);
  return ref.read(devotionalRepositoryProvider).getList(category: category);
});

final devotionalDetailProvider =
    FutureProvider.family<Devotional, int>((ref, id) {
  return ref.read(devotionalRepositoryProvider).getDetail(id);
});

// ── Prayer ────────────────────────────────────────────────────────────────────

final prayerListProvider = StateNotifierProvider<PrayerListNotifier, AsyncValue<List<Prayer>>>((ref) {
  return PrayerListNotifier(ref.read(prayerRepositoryProvider));
});

class PrayerListNotifier extends StateNotifier<AsyncValue<List<Prayer>>> {
  final PrayerRepository _repo;
  PrayerListNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({String? type, String? status, String? search}) async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getList(prayerType: type, status: status, search: search);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    await load();
  }

  Future<void> markAnswered(int id, {String note = ''}) async {
    await _repo.markAnswered(id, note: note);
    await load();
  }
}

final prayerStatsProvider = FutureProvider<PrayerStats>((ref) {
  return ref.read(prayerRepositoryProvider).getStats();
});

final prayerCategoriesProvider = FutureProvider<List<PrayerCategory>>((ref) {
  return ref.read(prayerRepositoryProvider).getCategories();
});

final prayerDetailProvider = FutureProvider.family<Prayer, int>((ref, id) {
  return ref.read(prayerRepositoryProvider).getDetail(id);
});

// ── Reading Plans ─────────────────────────────────────────────────────────────

final readingPlansProvider = FutureProvider<List<ReadingPlan>>((ref) {
  return ref.read(planRepositoryProvider).getPlans();
});

final myPlansProvider = StateNotifierProvider<MyPlansNotifier, AsyncValue<List<UserReadingPlan>>>((ref) {
  return MyPlansNotifier(ref.read(planRepositoryProvider));
});

class MyPlansNotifier extends StateNotifier<AsyncValue<List<UserReadingPlan>>> {
  final ReadingPlanRepository _repo;
  MyPlansNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getMyPlans();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> enroll(int planId) async {
    await _repo.enroll(planId);
    await load();
  }

  Future<void> completeDay(int userPlanId, {int? dayNumber}) async {
    await _repo.completeDay(userPlanId, dayNumber: dayNumber);
    await load();
  }

  Future<void> pause(int id) async {
    await _repo.pause(id);
    await load();
  }

  Future<void> resume(int id) async {
    await _repo.resume(id);
    await load();
  }
}

final readingStreakProvider = FutureProvider<ReadingStreak>((ref) {
  return ref.read(planRepositoryProvider).getStreak();
});

// ── AI ────────────────────────────────────────────────────────────────────────

final chatMessagesProvider =
    StateNotifierProvider.family<ChatNotifier, List<ChatMessage>, int?>((ref, sessionId) {
  return ChatNotifier(ref.read(aiRepositoryProvider), sessionId);
});

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final AiRepository _repo;
  int? sessionId;

  ChatNotifier(this._repo, this.sessionId) : super([]);

  Future<void> send(String message) async {
    // Optimistically add user message
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      role: 'user',
      content: message,
      createdAt: DateTime.now().toIso8601String(),
    );
    state = [...state, userMsg];

    // Add thinking placeholder
    final thinkingMsg = ChatMessage(
      id: -1,
      role: 'assistant',
      content: '...',
      createdAt: DateTime.now().toIso8601String(),
    );
    state = [...state, thinkingMsg];

    try {
      final result = await _repo.chat(message: message, sessionId: sessionId);
      sessionId = result['session_id'];
      final aiMsg = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch + 1,
        role: 'assistant',
        content: result['response'] as String,
        createdAt: DateTime.now().toIso8601String(),
      );
      state = [...state.where((m) => m.id != -1), aiMsg];
    } catch (e) {
      state = state.where((m) => m.id != -1).toList();
    }
  }
}

final aiStudyHistoryProvider = FutureProvider<List<StudySession>>((ref) {
  return ref.read(aiRepositoryProvider).getStudyHistory();
});

final chatSessionsProvider = FutureProvider<List<ChatSession>>((ref) {
  return ref.read(aiRepositoryProvider).getSessions();
});

final dailyEncouragementProvider = FutureProvider<String>((ref) {
  return ref.read(aiRepositoryProvider).dailyEncouragement();
});

// ── Notifications ─────────────────────────────────────────────────────────────

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, AsyncValue<List<AppNotification>>>((ref) {
  return NotificationsNotifier(ref.read(notificationRepositoryProvider));
});

final unreadOnlyProvider = StateProvider<bool>((ref) => false);

class NotificationsNotifier extends StateNotifier<AsyncValue<List<AppNotification>>> {
  final NotificationRepository _repo;
  NotificationsNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool unreadOnly = false}) async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getList(unreadOnly: unreadOnly);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markRead(int id) async {
    await _repo.markRead(id);
    state = state.whenData((list) =>
        list.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList());
  }

  Future<void> markAllRead() async {
    await _repo.markAllRead();
    state = state.whenData(
        (list) => list.map((n) => n.copyWith(isRead: true)).toList());
  }
}

final unreadCountProvider = FutureProvider<int>((ref) {
  return ref.read(notificationRepositoryProvider).getUnreadCount();
});

// ── Analytics ─────────────────────────────────────────────────────────────────

final dashboardProvider = FutureProvider<Dashboard>((ref) {
  return ref.read(analyticsRepositoryProvider).getDashboard();
});

final heatmapProvider = FutureProvider<Map<String, int>>((ref) {
  return ref.read(analyticsRepositoryProvider).getHeatmap();
});

final weeklyReportProvider = FutureProvider<WeeklyReport>((ref) {
  return ref.read(analyticsRepositoryProvider).getWeeklyReport();
});

final selectedAnalyticsMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final monthlyReportProvider = FutureProvider<MonthlyReport>((ref) {
  final selected = ref.watch(selectedAnalyticsMonthProvider);
  return ref
      .read(analyticsRepositoryProvider)
      .getMonthlyReport(year: selected.year, month: selected.month);
});

// ── NOTES ─────────────────────────────────────────────────────────────────────

final notesTopicsProvider = StateNotifierProvider<NotesNotifier, AsyncValue<List<NoteTopic>>>((ref) {
  return NotesNotifier(ref.read(notesRepositoryProvider));
});

class NotesNotifier extends StateNotifier<AsyncValue<List<NoteTopic>>> {
  final NotesRepository _repo;
  NotesNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final topics = await _repo.getAllTopics();
      state = AsyncValue.data(topics);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createTopic(String name, {String description = ''}) async {
    await _repo.createTopic(name, description: description);
    await load();
  }

  Future<void> deleteTopic(String id) async {
    await _repo.deleteTopic(id);
    await load();
  }
}

final notesProvider = StateNotifierProvider<AllNotesNotifier, AsyncValue<List<Note>>>((ref) {
  return AllNotesNotifier(ref.read(notesRepositoryProvider));
});

class AllNotesNotifier extends StateNotifier<AsyncValue<List<Note>>> {
  final NotesRepository _repo;
  AllNotesNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final notes = await _repo.getAllNotes();
      state = AsyncValue.data(notes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final notesByTopicProvider = FutureProvider.family<List<Note>, String>((ref, topicId) {
  return ref.read(notesRepositoryProvider).getNotesByTopic(topicId);
});

final favoritesNotesProvider = FutureProvider<List<Note>>((ref) {
  return ref.read(notesRepositoryProvider).getFavorites();
});

final searchNotesProvider = StateProvider<String>((ref) => '');

final searchNotesResultsProvider = FutureProvider<List<Note>>((ref) {
  final query = ref.watch(searchNotesProvider);
  if (query.isEmpty) return Future.value([]);
  return ref.read(notesRepositoryProvider).searchNotes(query);
});

// ── UNIVERSAL RULES ──────────────────────────────────────────────────────────

final universalRulesProvider = StateNotifierProvider<RulesNotifier, AsyncValue<List<UniversalRule>>>((ref) {
  return RulesNotifier(ref.read(rulesRepositoryProvider));
});

class RulesNotifier extends StateNotifier<AsyncValue<List<UniversalRule>>> {
  final UniversalRulesRepository _repo;
  RulesNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final rules = await _repo.getActiveRules();
      state = AsyncValue.data(rules);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteRule(String id) async {
    await _repo.deleteRule(id);
    await load();
  }

  Future<void> markCompleted(String id) async {
    await _repo.markCompleted(id);
    await load();
  }

  Future<void> togglePin(String id) async {
    await _repo.togglePin(id);
    await load();
  }
}

final todaysRulesProvider = FutureProvider<List<UniversalRule>>((ref) {
  return ref.read(rulesRepositoryProvider).getTodaysRules();
});

final archivedRulesProvider = FutureProvider<List<UniversalRule>>((ref) {
  return ref.read(rulesRepositoryProvider).getArchivedRules();
});

// ── REMINDERS ─────────────────────────────────────────────────────────────────

final remindersProvider = StateNotifierProvider<RemindersNotifier, AsyncValue<List<Reminder>>>((ref) {
  return RemindersNotifier(ref.read(remindersRepositoryProvider));
});

class RemindersNotifier extends StateNotifier<AsyncValue<List<Reminder>>> {
  final RemindersRepository _repo;
  RemindersNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final reminders = await _repo.getActiveReminders();
      state = AsyncValue.data(reminders);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(Reminder reminder) async {
    await _repo.createReminder(
      title: reminder.title,
      description: reminder.description,
      category: reminder.category,
      scheduledTime: reminder.scheduledTime,
      frequency: reminder.frequency,
      repeatUntil: reminder.repeatUntil,
      daysOfWeek: reminder.daysOfWeek,
      repeatUntilCompleted: reminder.repeatUntilCompleted,
      snoozeDurationMinutes: reminder.snoozeDurationMinutes,
    );
    await load();
  }

  Future<void> deleteReminder(String id) async {
    await _repo.deleteReminder(id);
    await load();
  }

  Future<void> toggleReminder(String id) async {
    await _repo.toggleReminder(id);
    await load();
  }

  Future<void> snooze(String id, Duration duration) async {
    await _repo.snoozeReminder(id, duration);
    await load();
  }
}

final upcomingRemindersProvider = FutureProvider<List<Reminder>>((ref) {
  return ref.read(remindersRepositoryProvider).getUpcomingReminders(const Duration(hours: 24));
});

final remindersByCategoryProvider = FutureProvider.family<List<Reminder>, ReminderCategory>((ref, category) {
  return ref.read(remindersRepositoryProvider).getRemindersByCategory(category);
});
