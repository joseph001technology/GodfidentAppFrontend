import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/achievement.dart';
import '../repositories/achievements_repository.dart';
import 'bible_provider.dart';

final achievementsRepositoryProvider = Provider((_) => AchievementsRepository());

final allAchievementsProvider = FutureProvider<List<Achievement>>((ref) {
  return ref.read(achievementsRepositoryProvider).getAll();
});

final userAchievementsProvider = FutureProvider<List<UserAchievement>>((ref) {
  return ref.read(achievementsRepositoryProvider).getUserAchievements();
});

final recentAchievementsProvider = FutureProvider<List<UserAchievement>>((ref) {
  return ref.read(achievementsRepositoryProvider).getRecent(limit: 5);
});

final prayerStreakProvider = FutureProvider<PrayerStreak>((ref) {
  return ref.read(achievementsRepositoryProvider).getPrayerStreak();
});

final bibleStreakProvider = FutureProvider<dynamic>((ref) {
  return ref.read(readingPlanRepositoryProvider).getStreak();
});
