import '../core/dio_client.dart';
import '../models/bible.dart';

class BibleRepository {
  final _dio = DioClient.instance;

  Future<List<BibleTranslation>> getTranslations() async {
    final res = await _dio.get('/api/bible/translations/');
    final list = res.data is List ? res.data : res.data['results'] ?? [];
    return (list as List).map((j) => BibleTranslation.fromJson(j)).toList();
  }

  Future<List<BibleBook>> getBooks({String? testament}) async {
    final res = await _dio.get('/api/bible/books/', queryParameters: {
      if (testament != null) 'testament': testament,
    });
    final list = res.data is List ? res.data : res.data['results'] ?? [];
    return (list as List).map((j) => BibleBook.fromJson(j)).toList();
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
    final list = res.data is List ? res.data : res.data['results'] ?? [];
    return (list as List).map((j) => BibleVerse.fromJson(j)).toList();
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
    final list = res.data['data'] ?? res.data;
    return (list as List).map((j) => CrossReference.fromJson(j)).toList();
  }

  // Bookmarks
  Future<List<Bookmark>> getBookmarks() async {
    final res = await _dio.get('/api/bible/bookmarks/');
    final list = res.data is List ? res.data : res.data['results'] ?? [];
    return (list as List).map((j) => Bookmark.fromJson(j)).toList();
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

  Future<void> deleteBookmark(int id) async {
    await _dio.delete('/api/bible/bookmarks/$id/');
  }

  // Highlights
  Future<List<Highlight>> getHighlights({String? color}) async {
    final res = await _dio.get('/api/bible/highlights/', queryParameters: {
      if (color != null) 'color': color,
    });
    final list = res.data is List ? res.data : res.data['results'] ?? [];
    return (list as List).map((j) => Highlight.fromJson(j)).toList();
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

  // Notes
  Future<List<VerseNote>> getNotes() async {
    final res = await _dio.get('/api/bible/notes/');
    final list = res.data is List ? res.data : res.data['results'] ?? [];
    return (list as List).map((j) => VerseNote.fromJson(j)).toList();
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

  Future<void> deleteNote(int id) async {
    await _dio.delete('/api/bible/notes/$id/');
  }
}
