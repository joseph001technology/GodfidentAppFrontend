import '../core/dio_client.dart';
import '../core/api_response.dart';
import '../models/bible.dart';
import '../models/bible_extras.dart';

class BibleRepository {
  final _dio = DioClient.instance;

  Future<List<BibleTranslation>> getTranslations() async {
    final res = await _dio.get('/api/bible/translations/');
    final list = readList(res.data);
    return (list).map((j) => BibleTranslation.fromJson(j)).toList();
  }

  Future<List<BibleBook>> getBooks({String? testament}) async {
    final res = await _dio.get('/api/bible/books/', queryParameters: {
      if (testament != null) 'testament': testament,
    });
    final list = readList(res.data);
    return (list).map((j) => BibleBook.fromJson(j)).toList();
  }

  Future<BibleVerse> getVerse({
    required String book,
    required int chapter,
    required int verse,
    String translation = 'KJV',
  }) async {
    final res = await _dio.get('/api/bible/verse/', queryParameters: {
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'translation': translation,
    });
    return BibleVerse.fromJson(res.data['data']);
  }

  Future<BibleChapter> getChapter({
    required String book,
    required int chapter,
    String translation = 'KJV',
  }) async {
    final res = await _dio.get('/api/bible/chapter/', queryParameters: {
      'book': book,
      'chapter': chapter,
      'translation': translation,
    });
    return BibleChapter.fromJson(res.data['data']);
  }

  Future<Map<String, String?>> getParallel({
    required String book,
    required int chapter,
    required int verse,
    List<String> translations = const ['KJV', 'NIV', 'ESV'],
  }) async {
    final res = await _dio.get('/api/bible/parallel/', queryParameters: {
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'translations': translations.join(','),
    });
    final data = res.data['data'];
    final raw = Map<String, dynamic>.from(data['translations'] ?? {});
    return raw.map((k, v) => MapEntry(k, v?.toString()));
  }

  Future<List<BibleVerse>> search({
    required String q,
    String translation = 'KJV',
    String? testament,
  }) async {
    final res = await _dio.get('/api/bible/search/', queryParameters: {
      'q': q,
      'translation': translation,
      if (testament != null) 'testament': testament,
    });
    final list = readList(res.data);
    return (list).map((j) => BibleVerse.fromJson(j)).toList();
  }

  Future<List<CrossReference>> getCrossReferences({
    required String book,
    required int chapter,
    required int verse,
  }) async {
    final res = await _dio.get('/api/bible/cross-references/', queryParameters: {
      'book': book,
      'chapter': chapter,
      'verse': verse,
    });
    final list = readList(res.data);
    return (list).map((j) => CrossReference.fromJson(j)).toList();
  }

  // Bookmarks
  Future<List<Bookmark>> getBookmarks() async {
    final res = await _dio.get('/api/bible/bookmarks/');
    final list = readList(res.data);
    return (list).map((j) => Bookmark.fromJson(j)).toList();
  }

  Future<Bookmark> createBookmark({
    required int bookId,
    required int chapter,
    required int verse,
    String note = '',
  }) async {
    final res = await _dio.post('/api/bible/bookmarks/', data: {
      'book': bookId,
      'chapter': chapter,
      'verse': verse,
      if (note.isNotEmpty) 'note': note,
    });
    return Bookmark.fromJson(res.data);
  }

  Future<Bookmark> updateBookmark(int id, {String note = ''}) async {
    final res = await _dio.patch('/api/bible/bookmarks/$id/', data: {'note': note});
    return Bookmark.fromJson(readMap(res.data));
  }

  Future<void> deleteBookmark(int id) async {
    await _dio.delete('/api/bible/bookmarks/$id/');
  }

  // Highlights
  Future<List<Highlight>> getHighlights({String? color}) async {
    final res = await _dio.get('/api/bible/highlights/', queryParameters: {
      if (color != null) 'color': color,
    });
    final list = readList(res.data);
    return (list).map((j) => Highlight.fromJson(j)).toList();
  }

  Future<Highlight> createHighlight({
    required int bookId,
    required int chapter,
    required int verse,
    String color = 'yellow',
    String note = '',
  }) async {
    final res = await _dio.post('/api/bible/highlights/', data: {
      'book': bookId,
      'chapter': chapter,
      'verse': verse,
      'color': color,
      if (note.isNotEmpty) 'note': note,
    });
    return Highlight.fromJson(res.data);
  }

  Future<Highlight> updateHighlight(int id, {String? color, String? note}) async {
    final res = await _dio.patch('/api/bible/highlights/$id/', data: {
      if (color != null) 'color': color,
      if (note != null) 'note': note,
    });
    return Highlight.fromJson(readMap(res.data));
  }

  Future<void> deleteHighlight(int id) async {
    await _dio.delete('/api/bible/highlights/$id/');
  }

  // Notes
  Future<List<VerseNote>> getNotes() async {
    final res = await _dio.get('/api/bible/notes/');
    final list = readList(res.data);
    return (list).map((j) => VerseNote.fromJson(j)).toList();
  }

  Future<VerseNote> createNote({
    required int bookId,
    required int chapter,
    required int verse,
    required String content,
  }) async {
    final res = await _dio.post('/api/bible/notes/', data: {
      'book': bookId,
      'chapter': chapter,
      'verse': verse,
      'content': content,
    });
    return VerseNote.fromJson(res.data);
  }

  Future<VerseNote> updateNote(int id, String content) async {
    final res = await _dio.patch('/api/bible/notes/$id/', data: {'content': content});
    return VerseNote.fromJson(res.data);
  }

  Future<BibleVerse> getVerseOfTheDay() async {
    final res = await _dio.get('/api/bible/verse-of-the-day/');
    final data = res.data['data'] ?? res.data;
    return BibleVerse.fromJson(data);
  }

  Future<Map<String, dynamic>> getReadingProgress() async {
    final res = await _dio.get('/api/bible/reading-progress/');
    final data = res.data['data'] ?? res.data;
    return {
      'location': '${data['book_name'] ?? 'Genesis'} ${data['chapter'] ?? 1}',
      'percent': (data['percent'] ?? 0.0) / 100.0,
    };
  }

  Future<void> saveReadingProgress({required String book, required int chapter}) async {
    await _dio.post('/api/bible/save-progress/', data: {
      'book': book,
      'chapter': chapter,
    });
  }

  Future<void> logReading({required String book, required int chapter}) async {
    await _dio.post('/api/analytics/log-reading/', data: {
      'book_name': book,
      'chapter': chapter,
    });
  }

  // ── Favorite Verses (/api/bible/favorites/) ─────────────────────
  Future<List<FavoriteVerse>> getFavoriteVerses() async {
    final res = await _dio.get('/api/bible/favorites/');
    return (readList(res.data)).map((j) => FavoriteVerse.fromJson(j)).toList();
  }

  Future<FavoriteVerse> addFavoriteVerse({
    required int bookId,
    required int chapter,
    required int verse,
    String note = '',
  }) async {
    final res = await _dio.post('/api/bible/favorites/', data: {
      'book': bookId,
      'chapter': chapter,
      'verse': verse,
      if (note.isNotEmpty) 'note': note,
    });
    return FavoriteVerse.fromJson(readMap(res.data));
  }

  Future<void> removeFavoriteVerse(int id) async {
    await _dio.delete('/api/bible/favorites/$id/');
  }

  // ── Verse Collections (/api/bible/collections/) ─────────────────
  Future<List<VerseCollection>> getVerseCollections() async {
    final res = await _dio.get('/api/bible/collections/');
    return (readList(res.data)).map((j) => VerseCollection.fromJson(j)).toList();
  }

  Future<VerseCollection> createVerseCollection(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/bible/collections/', data: data);
    return VerseCollection.fromJson(readMap(res.data));
  }

  Future<VerseCollection> updateVerseCollection(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/bible/collections/$id/', data: data);
    return VerseCollection.fromJson(readMap(res.data));
  }

  Future<void> deleteVerseCollection(int id) async {
    await _dio.delete('/api/bible/collections/$id/');
  }

  // ── Reading Goals (/api/bible/reading-goals/) ───────────────────
  Future<List<BibleReadingGoal>> getReadingGoals() async {
    final res = await _dio.get('/api/bible/reading-goals/');
    return (readList(res.data)).map((j) => BibleReadingGoal.fromJson(j)).toList();
  }

  Future<BibleReadingGoal> createReadingGoal(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/bible/reading-goals/', data: data);
    return BibleReadingGoal.fromJson(readMap(res.data));
  }

  Future<BibleReadingGoal> updateReadingGoal(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/bible/reading-goals/$id/', data: data);
    return BibleReadingGoal.fromJson(readMap(res.data));
  }

  Future<void> deleteReadingGoal(int id) async {
    await _dio.delete('/api/bible/reading-goals/$id/');
  }

  // ── Global Search (/api/search/) ────────────────────────────────
  Future<Map<String, List<Map<String, dynamic>>>> globalSearch(String q) async {
    final res = await _dio.get('/api/search/', queryParameters: {'q': q});
    final data = readDataMap(res.data);
    final out = <String, List<Map<String, dynamic>>>{};
    for (final entry in data.entries) {
      final list = entry.value;
      if (list is List) {
        out[entry.key] = list
            .map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }
    return out;
  }
}
