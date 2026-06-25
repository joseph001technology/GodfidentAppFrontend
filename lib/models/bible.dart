class BibleTranslation {
  final int id;
  final String code;
  final String name;
  final String fullName;
  final String language;

  const BibleTranslation({
    required this.id,
    required this.code,
    required this.name,
    required this.fullName,
    required this.language,
  });

  factory BibleTranslation.fromJson(Map<String, dynamic> j) => BibleTranslation(
        id: j['id'] ?? 0,
        code: j['code'] ?? '',
        name: j['name'] ?? '',
        fullName: j['full_name'] ?? '',
        language: j['language'] ?? 'English',
      );
}

class BibleBook {
  final int id;
  final int number;
  final String name;
  final String abbreviation;
  final String testament;
  final int chapterCount;

  const BibleBook({
    required this.id,
    required this.number,
    required this.name,
    required this.abbreviation,
    required this.testament,
    required this.chapterCount,
  });

  factory BibleBook.fromJson(Map<String, dynamic> j) => BibleBook(
        id: j['id'] ?? 0,
        number: j['number'] ?? 0,
        name: j['name'] ?? '',
        abbreviation: j['abbreviation'] ?? '',
        testament: j['testament'] ?? 'OT',
        chapterCount: j['chapter_count'] ?? 0,
      );

  bool get isOldTestament => testament == 'OT';
}

class BibleVerse {
  final int id;
  final String translationCode;
  final String bookName;
  final int chapter;
  final int verse;
  final String text;
  final String reference;

  const BibleVerse({
    required this.id,
    required this.translationCode,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.reference,
  });

  factory BibleVerse.fromJson(Map<String, dynamic> j) => BibleVerse(
        id: j['id'] ?? 0,
        translationCode: j['translation_code'] ?? '',
        bookName: j['book_name'] ?? '',
        chapter: j['chapter'] ?? 0,
        verse: j['verse'] ?? 0,
        text: j['text'] ?? '',
        reference: j['reference'] ?? '',
      );
}

class BibleChapter {
  final String translation;
  final String book;
  final int bookNumber;
  final int chapter;
  final int totalChapters;
  final List<BibleVerse> verses;

  const BibleChapter({
    required this.translation,
    required this.book,
    required this.bookNumber,
    required this.chapter,
    required this.totalChapters,
    required this.verses,
  });

  factory BibleChapter.fromJson(Map<String, dynamic> j) => BibleChapter(
        translation: j['translation'] ?? '',
        book: j['book'] ?? '',
        bookNumber: j['book_number'] ?? 0,
        chapter: j['chapter'] ?? 0,
        totalChapters: j['total_chapters'] ?? 0,
        verses: (j['verses'] as List? ?? [])
            .map((v) => BibleVerse.fromJson(v))
            .toList(),
      );

  bool get hasPrevious => chapter > 1;
  bool get hasNext => chapter < totalChapters;
}

class CrossReference {
  final int id;
  final String toBookName;
  final int toChapter;
  final int toVerse;
  final int? toVerseEnd;
  final double relevanceScore;
  final String reference;

  const CrossReference({
    required this.id,
    required this.toBookName,
    required this.toChapter,
    required this.toVerse,
    this.toVerseEnd,
    required this.relevanceScore,
    required this.reference,
  });

  factory CrossReference.fromJson(Map<String, dynamic> j) => CrossReference(
        id: j['id'] ?? 0,
        toBookName: j['to_book_name'] ?? '',
        toChapter: j['to_chapter'] ?? 0,
        toVerse: j['to_verse'] ?? 0,
        toVerseEnd: j['to_verse_end'],
        relevanceScore: (j['relevance_score'] ?? 1.0).toDouble(),
        reference: j['reference'] ?? '',
      );
}

class Bookmark {
  final int id;
  final int book;
  final String bookName;
  final int chapter;
  final int verse;
  final String note;
  final String reference;
  final String createdAt;

  const Bookmark({
    required this.id,
    required this.book,
    required this.bookName,
    required this.chapter,
    required this.verse,
    this.note = '',
    required this.reference,
    required this.createdAt,
  });

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
        id: j['id'] ?? 0,
        book: j['book'] ?? 0,
        bookName: j['book_name'] ?? '',
        chapter: j['chapter'] ?? 0,
        verse: j['verse'] ?? 0,
        note: j['note'] ?? '',
        reference: j['reference'] ?? '',
        createdAt: j['created_at'] ?? '',
      );
}

class Highlight {
  final int id;
  final int book;
  final String bookName;
  final int chapter;
  final int verse;
  final String color;
  final String note;
  final String reference;
  final String createdAt;

  const Highlight({
    required this.id,
    required this.book,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.color,
    this.note = '',
    required this.reference,
    required this.createdAt,
  });

  factory Highlight.fromJson(Map<String, dynamic> j) => Highlight(
        id: j['id'] ?? 0,
        book: j['book'] ?? 0,
        bookName: j['book_name'] ?? '',
        chapter: j['chapter'] ?? 0,
        verse: j['verse'] ?? 0,
        color: j['color'] ?? 'yellow',
        note: j['note'] ?? '',
        reference: j['reference'] ?? '',
        createdAt: j['created_at'] ?? '',
      );
}

class VerseNote {
  final int id;
  final int book;
  final String bookName;
  final int chapter;
  final int verse;
  final String content;
  final String updatedAt;

  const VerseNote({
    required this.id,
    required this.book,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.content,
    required this.updatedAt,
  });

  factory VerseNote.fromJson(Map<String, dynamic> j) => VerseNote(
        id: j['id'] ?? 0,
        book: j['book'] ?? 0,
        bookName: j['book_name'] ?? '',
        chapter: j['chapter'] ?? 0,
        verse: j['verse'] ?? 0,
        content: j['content'] ?? '',
        updatedAt: j['updated_at'] ?? '',
      );
}
