import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bible_extras.dart';
import 'bible_provider.dart';

// ── Verse Collections ───────────────────────────────────────────────
final verseCollectionsProvider = FutureProvider<List<VerseCollection>>((ref) {
  return ref.read(bibleRepositoryProvider).getVerseCollections();
});

// ── Favorite Verses ─────────────────────────────────────────────────
final favoriteVersesProvider = FutureProvider<List<FavoriteVerse>>((ref) {
  return ref.read(bibleRepositoryProvider).getFavoriteVerses();
});

// ── Bible Reading Goals ─────────────────────────────────────────────
final bibleReadingGoalsProvider = FutureProvider<List<BibleReadingGoal>>((ref) {
  return ref.read(bibleRepositoryProvider).getReadingGoals();
});

// ── Global Search ───────────────────────────────────────────────────
/// Family provider keyed by the query string. Returns grouped results
/// from /api/search/?q=... (keys: bible, notes, rules, bookmarks,
/// prayer_journal, reminders).
final globalSearchProvider =
    FutureProvider.family<Map<String, List<Map<String, dynamic>>>, String>((ref, query) {
  if (query.trim().isEmpty) return Future.value({});
  return ref.read(bibleRepositoryProvider).globalSearch(query.trim());
});
