/// A user's favorite verse (from /api/bible/favorites/).
class FavoriteVerse {
  final int id;
  final int book;
  final String bookName;
  final int chapter;
  final int verse;
  final String note;
  final int order;
  final String reference;
  final String createdAt;

  const FavoriteVerse({
    required this.id,
    required this.book,
    required this.bookName,
    required this.chapter,
    required this.verse,
    this.note = '',
    this.order = 0,
    required this.reference,
    required this.createdAt,
  });

  factory FavoriteVerse.fromJson(Map<String, dynamic> j) => FavoriteVerse(
        id: j['id'] ?? 0,
        book: j['book'] ?? 0,
        bookName: j['book_name'] ?? '',
        chapter: j['chapter'] ?? 0,
        verse: j['verse'] ?? 0,
        note: j['note'] ?? '',
        order: j['order'] ?? 0,
        reference: j['reference'] ?? '',
        createdAt: j['created_at'] ?? '',
      );
}

/// A named collection of verses (from /api/bible/collections/).
class VerseCollection {
  final int id;
  final String name;
  final String description;
  final List<int> verses;
  final bool isPublic;
  final String createdAt;
  final String updatedAt;

  const VerseCollection({
    required this.id,
    required this.name,
    this.description = '',
    this.verses = const [],
    this.isPublic = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VerseCollection.fromJson(Map<String, dynamic> j) => VerseCollection(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        description: j['description'] ?? '',
        verses: (j['verses'] as List? ?? [])
            .map((e) => e is int ? e : int.tryParse('$e') ?? 0)
            .toList(),
        isPublic: j['is_public'] ?? false,
        createdAt: j['created_at'] ?? '',
        updatedAt: j['updated_at'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'verses': verses,
        'is_public': isPublic,
      };
}

/// A Bible reading goal (from /api/bible/reading-goals/).
/// Backend fields: id, chapters_target, period, is_active, created_at, updated_at.
class BibleReadingGoal {
  final int id;
  final int chaptersTarget;
  final String period; // 'daily' | 'weekly' | 'monthly' | 'yearly'
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const BibleReadingGoal({
    required this.id,
    required this.chaptersTarget,
    required this.period,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BibleReadingGoal.fromJson(Map<String, dynamic> j) => BibleReadingGoal(
        id: j['id'] ?? 0,
        chaptersTarget: j['chapters_target'] ?? 0,
        period: j['period'] ?? 'daily',
        isActive: j['is_active'] ?? true,
        createdAt: j['created_at'] ?? '',
        updatedAt: j['updated_at'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'chapters_target': chaptersTarget,
        'period': period,
        'is_active': isActive,
      };
}
