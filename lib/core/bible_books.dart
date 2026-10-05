/// The 66 books of the Bible, kept on the phone so book search is instant and
/// works with no internet. Names match the server's book names exactly.
class BookInfo {
  final int number;
  final String name;
  final String abbr;
  final String testament; // OT | NT
  final int chapters;
  const BookInfo(this.number, this.name, this.abbr, this.testament, this.chapters);
}

/// What a search box text means as a Bible location.
class BookMatch {
  final BookInfo book;

  /// Set when the text also named a chapter ("John 3") / verse ("John 3:16").
  final int? chapter;
  final int? verse;
  const BookMatch(this.book, {this.chapter, this.verse});

  bool get hasChapter => chapter != null;

  String get label {
    if (chapter == null) return book.name;
    return verse == null ? '${book.name} $chapter' : '${book.name} $chapter:$verse';
  }
}

class BibleBooks {
  BibleBooks._();

  static const all = <BookInfo>[
    BookInfo(1, 'Genesis', 'Gen', 'OT', 50), BookInfo(2, 'Exodus', 'Exo', 'OT', 40),
    BookInfo(3, 'Leviticus', 'Lev', 'OT', 27), BookInfo(4, 'Numbers', 'Num', 'OT', 36),
    BookInfo(5, 'Deuteronomy', 'Deu', 'OT', 34), BookInfo(6, 'Joshua', 'Jos', 'OT', 24),
    BookInfo(7, 'Judges', 'Jdg', 'OT', 21), BookInfo(8, 'Ruth', 'Rut', 'OT', 4),
    BookInfo(9, '1 Samuel', '1Sa', 'OT', 31), BookInfo(10, '2 Samuel', '2Sa', 'OT', 24),
    BookInfo(11, '1 Kings', '1Ki', 'OT', 22), BookInfo(12, '2 Kings', '2Ki', 'OT', 25),
    BookInfo(13, '1 Chronicles', '1Ch', 'OT', 29), BookInfo(14, '2 Chronicles', '2Ch', 'OT', 36),
    BookInfo(15, 'Ezra', 'Ezr', 'OT', 10), BookInfo(16, 'Nehemiah', 'Neh', 'OT', 13),
    BookInfo(17, 'Esther', 'Est', 'OT', 10), BookInfo(18, 'Job', 'Job', 'OT', 42),
    BookInfo(19, 'Psalms', 'Psa', 'OT', 150), BookInfo(20, 'Proverbs', 'Pro', 'OT', 31),
    BookInfo(21, 'Ecclesiastes', 'Ecc', 'OT', 12), BookInfo(22, 'Song of Solomon', 'Son', 'OT', 8),
    BookInfo(23, 'Isaiah', 'Isa', 'OT', 66), BookInfo(24, 'Jeremiah', 'Jer', 'OT', 52),
    BookInfo(25, 'Lamentations', 'Lam', 'OT', 5), BookInfo(26, 'Ezekiel', 'Eze', 'OT', 48),
    BookInfo(27, 'Daniel', 'Dan', 'OT', 12), BookInfo(28, 'Hosea', 'Hos', 'OT', 14),
    BookInfo(29, 'Joel', 'Joe', 'OT', 3), BookInfo(30, 'Amos', 'Amo', 'OT', 9),
    BookInfo(31, 'Obadiah', 'Oba', 'OT', 1), BookInfo(32, 'Jonah', 'Jon', 'OT', 4),
    BookInfo(33, 'Micah', 'Mic', 'OT', 7), BookInfo(34, 'Nahum', 'Nah', 'OT', 3),
    BookInfo(35, 'Habakkuk', 'Hab', 'OT', 3), BookInfo(36, 'Zephaniah', 'Zep', 'OT', 3),
    BookInfo(37, 'Haggai', 'Hag', 'OT', 2), BookInfo(38, 'Zechariah', 'Zec', 'OT', 14),
    BookInfo(39, 'Malachi', 'Mal', 'OT', 4),
    BookInfo(40, 'Matthew', 'Mat', 'NT', 28), BookInfo(41, 'Mark', 'Mar', 'NT', 16),
    BookInfo(42, 'Luke', 'Luk', 'NT', 24), BookInfo(43, 'John', 'Joh', 'NT', 21),
    BookInfo(44, 'Acts', 'Act', 'NT', 28), BookInfo(45, 'Romans', 'Rom', 'NT', 16),
    BookInfo(46, '1 Corinthians', '1Co', 'NT', 16), BookInfo(47, '2 Corinthians', '2Co', 'NT', 13),
    BookInfo(48, 'Galatians', 'Gal', 'NT', 6), BookInfo(49, 'Ephesians', 'Eph', 'NT', 6),
    BookInfo(50, 'Philippians', 'Phi', 'NT', 4), BookInfo(51, 'Colossians', 'Col', 'NT', 4),
    BookInfo(52, '1 Thessalonians', '1Th', 'NT', 5), BookInfo(53, '2 Thessalonians', '2Th', 'NT', 3),
    BookInfo(54, '1 Timothy', '1Ti', 'NT', 6), BookInfo(55, '2 Timothy', '2Ti', 'NT', 4),
    BookInfo(56, 'Titus', 'Tit', 'NT', 3), BookInfo(57, 'Philemon', 'Phm', 'NT', 1),
    BookInfo(58, 'Hebrews', 'Heb', 'NT', 13), BookInfo(59, 'James', 'Jam', 'NT', 5),
    BookInfo(60, '1 Peter', '1Pe', 'NT', 5), BookInfo(61, '2 Peter', '2Pe', 'NT', 3),
    BookInfo(62, '1 John', '1Jo', 'NT', 5), BookInfo(63, '2 John', '2Jo', 'NT', 1),
    BookInfo(64, '3 John', '3Jo', 'NT', 1), BookInfo(65, 'Jude', 'Jud', 'NT', 1),
    BookInfo(66, 'Revelation', 'Rev', 'NT', 22),
  ];

  /// Common extra spellings, lower case, no spaces.
  static const _alias = <String, String>{
    'psalm': 'Psalms', 'ps': 'Psalms', 'psa': 'Psalms',
    'songofsongs': 'Song of Solomon', 'song': 'Song of Solomon', 'sos': 'Song of Solomon',
    'revelations': 'Revelation', 'rev': 'Revelation',
    'jn': 'John', 'mt': 'Matthew', 'mk': 'Mark', 'lk': 'Luke', 'rm': 'Romans',
    'gn': 'Genesis', 'ex': 'Exodus', 'dt': 'Deuteronomy', 'jb': 'Job', 'prov': 'Proverbs',
    'is': 'Isaiah', 'jer': 'Jeremiah', 'heb': 'Hebrews', 'jas': 'James',
  };

  static final _numberWords = <String, String>{'first': '1', 'second': '2', 'third': '3', 'i': '1', 'ii': '2', 'iii': '3'};

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// "1 jn" / "1jn" / "first john" -> "1 john"-style key without spaces: "1john".
  static String _key(String s) {
    var t = _norm(s);
    final parts = t.split(' ');
    if (parts.length > 1 && _numberWords.containsKey(parts.first)) {
      t = '${_numberWords[parts.first]} ${parts.sublist(1).join(' ')}';
    }
    return t.replaceAll(' ', '');
  }

  static BookInfo? byName(String name) {
    for (final b in all) {
      if (b.name.toLowerCase() == name.toLowerCase()) return b;
    }
    return null;
  }

  /// Books whose NAME STARTS with what was typed (best first), e.g. "jo" ->
  /// Job, Joel, John, Jonah, Joshua; "1 co" -> 1 Corinthians. Falls back to
  /// "contains" so "solomon" still finds Song of Solomon.
  static List<BookInfo> search(String query) {
    final k = _key(query);
    if (k.isEmpty) return const [];
    var aliasTarget = _alias[k];
    if (aliasTarget == null && k.length > 1 && '123'.contains(k[0])) {
      // "1jn" -> "1 John", "2ti" handled by abbreviations, "1pet" by prefix
      final rest = _alias[k.substring(1)];
      if (rest != null) aliasTarget = '${k[0]} $rest';
    }
    final starts = <BookInfo>[];
    final contains = <BookInfo>[];
    for (final b in all) {
      final bk = _key(b.name);
      if (bk.startsWith(k) || b.abbr.toLowerCase() == k || (aliasTarget != null && b.name == aliasTarget)) {
        starts.add(b);
      } else if (k.length >= 3 && bk.contains(k)) {
        contains.add(b);
      }
    }
    return [...starts, ...contains];
  }

  /// Understands "John", "John 3", "john 3:16", "1 jn 4", "ps 23:1", "gen1".
  /// Returns the matching books (with chapter/verse when typed), best first.
  static List<BookMatch> parse(String input) {
    final q = input.trim();
    if (q.isEmpty) return const [];
    final m = RegExp(r'^(.*?[a-zA-Z.])\s*(\d{1,3})?(?:\s*[:.\s]\s*(\d{1,3}))?$').firstMatch(q);
    if (m == null) return search(q).map((b) => BookMatch(b)).toList();
    final namePart = m.group(1)!;
    final ch = int.tryParse(m.group(2) ?? '');
    final vs = int.tryParse(m.group(3) ?? '');
    final books = search(namePart);
    return [
      for (final b in books)
        if (ch == null)
          BookMatch(b)
        else if (ch >= 1 && ch <= b.chapters)
          BookMatch(b, chapter: ch, verse: vs)
    ];
  }
}
