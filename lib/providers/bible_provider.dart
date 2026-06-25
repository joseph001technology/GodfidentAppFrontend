import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bible.dart';
import '../repositories/bible_repository.dart';

final bibleRepositoryProvider = Provider((_) => BibleRepository());

final translationsProvider = FutureProvider<List<BibleTranslation>>((ref) {
  return ref.read(bibleRepositoryProvider).getTranslations();
});

final booksProvider = FutureProvider<List<BibleBook>>((ref) {
  return ref.read(bibleRepositoryProvider).getBooks();
});

final otBooksProvider = FutureProvider<List<BibleBook>>((ref) {
  return ref.read(bibleRepositoryProvider).getBooks(testament: 'OT');
});

final ntBooksProvider = FutureProvider<List<BibleBook>>((ref) {
  return ref.read(bibleRepositoryProvider).getBooks(testament: 'NT');
});

// Selected translation state
final selectedTranslationProvider = StateProvider<String>((ref) => 'KJV');

// Chapter provider
final chapterProvider = FutureProvider.family<BibleChapter, ChapterParams>((ref, p) {
  return ref.read(bibleRepositoryProvider).getChapter(
        book: p.book,
        chapter: p.chapter,
        translation: p.translation,
      );
});

class ChapterParams {
  final String book;
  final int chapter;
  final String translation;
  const ChapterParams(this.book, this.chapter, this.translation);
  @override
  bool operator ==(Object other) =>
      other is ChapterParams &&
      other.book == book &&
      other.chapter == chapter &&
      other.translation == translation;
  @override
  int get hashCode => Object.hash(book, chapter, translation);
}

// Cross references
final crossRefsProvider =
    FutureProvider.family<List<CrossReference>, VerseRef>((ref, v) {
  return ref.read(bibleRepositoryProvider).getCrossReferences(
        book: v.book,
        chapter: v.chapter,
        verse: v.verse,
      );
});

class VerseRef {
  final String book;
  final int chapter;
  final int verse;
  const VerseRef(this.book, this.chapter, this.verse);
  @override
  bool operator ==(Object other) =>
      other is VerseRef &&
      other.book == book &&
      other.chapter == chapter &&
      other.verse == verse;
  @override
  int get hashCode => Object.hash(book, chapter, verse);
}

// Search
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<BibleVerse>>((ref) {
  final q = ref.watch(searchQueryProvider);
  final translation = ref.watch(selectedTranslationProvider);
  if (q.isEmpty) return Future.value([]);
  return ref.read(bibleRepositoryProvider).search(q: q, translation: translation);
});

// Bookmarks
final bookmarksProvider = FutureProvider<List<Bookmark>>((ref) {
  return ref.read(bibleRepositoryProvider).getBookmarks();
});

// Highlights
final highlightsProvider = FutureProvider<List<Highlight>>((ref) {
  return ref.read(bibleRepositoryProvider).getHighlights();
});

// Notes
final verseNotesProvider = FutureProvider<List<VerseNote>>((ref) {
  return ref.read(bibleRepositoryProvider).getNotes();
});
