import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/bible.dart';
import '../../providers/bible_provider.dart';
import '../../repositories/analytics_repository.dart';
import '../../services/reader_settings.dart';
import '../../widgets/common/app_widgets.dart';
import 'reader_settings_sheet.dart';

/// Highlighter colours the server accepts (yellow | green | blue | pink | orange).
const Map<String, Color> kHighlightColors = {
  'yellow': Color(0xFFFFE066),
  'green': Color(0xFFA8E6A1),
  'blue': Color(0xFFA5D3F5),
  'pink': Color(0xFFF7B6CC),
  'orange': Color(0xFFFFC38A),
};

class ChapterScreen extends ConsumerStatefulWidget {
  final String book;
  final int chapter;
  final String translation;
  final int? focusVerse;

  /// Opened by "take me back to where I was": scroll there but don't select the verse.
  final bool resume;

  const ChapterScreen({
    super.key,
    required this.book,
    required this.chapter,
    required this.translation,
    this.focusVerse,
    this.resume = false,
  });

  @override
  ConsumerState<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends ConsumerState<ChapterScreen> {
  Timer? _logTimer;
  Timer? _posTimer;
  bool _logged = false;
  final Set<int> _selected = <int>{};
  int? _anchor; // last verse tapped, for range selection
  final _scroll = ScrollController();
  bool _jumped = false;
  int _topVerse = 1;
  double _avgHeight = 120;
  int _verseCount = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.resume && widget.focusVerse != null) {
      _selected.add(widget.focusVerse!);
      _anchor = widget.focusVerse;
    }
    _logTimer = Timer(const Duration(seconds: 10), _logReading);
    // "Continue reading" and the Bible tab start from here.
    ReadingPositionStore.save(widget.book, widget.chapter, widget.translation,
        verse: widget.resume ? (widget.focusVerse ?? 1) : 1);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _logTimer?.cancel();
    _posTimer?.cancel();
    // Save the exact spot synchronously-ish on the way out.
    ReadingPositionStore.save(widget.book, widget.chapter, widget.translation, verse: _topVerse);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    _posTimer?.cancel();
    _posTimer = Timer(const Duration(milliseconds: 500), () {
      if (!_scroll.hasClients || _verseCount == 0) return;
      final idx = (_scroll.offset / _avgHeight).floor().clamp(0, _verseCount - 1);
      _topVerse = idx + 1;
      ReadingPositionStore.save(widget.book, widget.chapter, widget.translation, verse: _topVerse);
    });
  }

  Future<void> _logReading() async {
    if (_logged) return;
    _logged = true;
    try {
      await AnalyticsRepository().logReading(
        bookName: widget.book,
        chapter: widget.chapter,
        translation: widget.translation,
      );
    } catch (_) {}
  }

  void _go(BibleChapter c, int delta) {
    context.pushReplacement(
      '/bible/chapter?book=${Uri.encodeComponent(c.book)}&chapter=${c.chapter + delta}&translation=${widget.translation}',
    );
  }

  /// Tap toggles a verse, so you can keep tapping to pick several.
  void _toggle(int v) => setState(() {
        if (!_selected.remove(v)) _selected.add(v);
        _anchor = v;
      });

  /// Long-press selects everything between the last tapped verse and this one.
  void _range(int v) => setState(() {
        final a = _anchor ?? v;
        final lo = a < v ? a : v;
        final hi = a < v ? v : a;
        for (var i = lo; i <= hi; i++) {
          _selected.add(i);
        }
        _anchor = v;
      });

  void _clear() => setState(() {
        _selected.clear();
        _anchor = null;
      });

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(readerSettingsProvider);
    final params = ChapterParams(widget.book, widget.chapter, widget.translation);
    final chapterAsync = ref.watch(chapterProvider(params));

    return chapterAsync.when(
      loading: () => Scaffold(
        backgroundColor: s.background,
        appBar: AppBar(title: Text('${widget.book} ${widget.chapter}')),
        body: const ShimmerList(count: 8),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppTheme.navy,
        appBar: AppBar(title: Text('${widget.book} ${widget.chapter}')),
        body: ErrorView(message: friendlyError(e), onRetry: () => ref.invalidate(chapterProvider(params))),
      ),
      data: (chapter) {
        _verseCount = chapter.verses.length;
        _avgHeight = s.fontSize * s.lineHeight * 2.6 + 16;
        _jumpToFocusVerse(chapter, s);
        return _ChapterView(
          scroll: _scroll,
          chapter: chapter,
          settings: s,
          selected: _selected,
          onToggle: _toggle,
          onRange: _range,
          onClear: _clear,
          onPrev: chapter.hasPrevious ? () => _go(chapter, -1) : null,
          onNext: chapter.hasNext ? () => _go(chapter, 1) : null,
        );
      },
    );
  }

  /// Opened from a search result / bookmark / "continue reading": scroll roughly to that verse.
  void _jumpToFocusVerse(BibleChapter chapter, ReaderSettings s) {
    final v = widget.focusVerse;
    if (_jumped || v == null || v <= 1) return;
    _jumped = true;
    _topVerse = v;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final idx = chapter.verses.indexWhere((x) => x.verse == v);
      if (idx <= 0) return;
      _scroll.jumpTo((idx * _avgHeight).clamp(0, _scroll.position.maxScrollExtent).toDouble());
    });
  }
}

class _ChapterView extends ConsumerWidget {
  final ScrollController scroll;
  final BibleChapter chapter;
  final ReaderSettings settings;
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final ValueChanged<int> onRange;
  final VoidCallback onClear;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _ChapterView({
    required this.scroll,
    required this.chapter,
    required this.settings,
    required this.selected,
    required this.onToggle,
    required this.onRange,
    required this.onClear,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = settings;
    final highlights = ref.watch(highlightsProvider).valueOrNull ?? const <Highlight>[];
    final bookmarks = ref.watch(bookmarksProvider).valueOrNull ?? const <Bookmark>[];
    final notes = ref.watch(verseNotesProvider).valueOrNull ?? const <VerseNote>[];

    T? find<T>(List<T> list, String Function(T) book, int Function(T) ch, int Function(T) vs, int v) {
      for (final x in list) {
        if (book(x) == chapter.book && ch(x) == chapter.chapter && vs(x) == v) return x;
      }
      return null;
    }

    Highlight? highlightOf(int v) => find<Highlight>(highlights, (h) => h.bookName, (h) => h.chapter, (h) => h.verse, v);
    Bookmark? bookmarkOf(int v) => find<Bookmark>(bookmarks, (b) => b.bookName, (b) => b.chapter, (b) => b.verse, v);
    VerseNote? noteOf(int v) => find<VerseNote>(notes, (n) => n.bookName, (n) => n.chapter, (n) => n.verse, v);

    final chapterNotes = notes.where((n) => n.bookName == chapter.book && n.chapter == chapter.chapter).toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));

    final actions = _SelectionActions(
      context: context,
      ref: ref,
      chapter: chapter,
      verses: [for (final v in chapter.verses) if (selected.contains(v.verse)) v],
      highlightOf: highlightOf,
      bookmarkOf: bookmarkOf,
      noteOf: noteOf,
      onDone: onClear,
    );

    return PopScope(
      canPop: selected.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onClear(); // first Back clears the selection
      },
      child: Scaffold(
        backgroundColor: s.background,
        appBar: AppBar(
          backgroundColor: s.background,
          foregroundColor: s.text,
          elevation: 0,
          iconTheme: IconThemeData(color: s.text),
          title: InkWell(
            onTap: () => context.go('/bible?browse=1'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(chapter.book,
                  style: TextStyle(fontFamily: 'Lora', fontSize: 20, fontWeight: FontWeight.bold, color: s.text)),
              Text('Chapter ${chapter.chapter} · ${chapter.translation}',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: s.text.withValues(alpha: 0.6))),
            ]),
          ),
          actions: [
            IconButton(
              tooltip: chapterNotes.isEmpty ? 'No notes in this chapter yet' : 'Notes in this chapter',
              icon: Badge(
                isLabelVisible: chapterNotes.isNotEmpty,
                label: Text('${chapterNotes.length}'),
                child: Icon(Icons.sticky_note_2_outlined, color: s.accent),
              ),
              onPressed: chapterNotes.isEmpty ? null : () => _showChapterNotes(context, ref, chapterNotes),
            ),
            IconButton(
              tooltip: 'Text size and theme',
              icon: Icon(Icons.text_fields_rounded, color: s.accent),
              onPressed: () => showReaderSettingsSheet(context),
            ),
            IconButton(
              tooltip: 'Previous chapter',
              icon: Icon(Icons.chevron_left, color: onPrev == null ? s.text.withValues(alpha: 0.25) : s.accent),
              onPressed: onPrev,
            ),
            IconButton(
              tooltip: 'Next chapter',
              icon: Icon(Icons.chevron_right, color: onNext == null ? s.text.withValues(alpha: 0.25) : s.accent),
              onPressed: onNext,
            ),
          ],
        ),
        body: GestureDetector(
          // Swipe left = next chapter, swipe right = previous.
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (selected.isNotEmpty) return;
            if (v < -500) onNext?.call();
            if (v > 500) onPrev?.call();
          },
          child: Column(children: [
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: chapter.verses.length,
                itemBuilder: (_, i) {
                  final v = chapter.verses[i];
                  final note = noteOf(v.verse);
                  return _VerseTile(
                    verse: v,
                    settings: s,
                    highlight: highlightOf(v.verse),
                    bookmark: bookmarkOf(v.verse),
                    note: note,
                    isSelected: selected.contains(v.verse),
                    onTap: () => onToggle(v.verse),
                    onLongPress: () => onRange(v.verse),
                    onNoteTap: note == null ? null : () => showVerseNoteSheet(context, ref, note),
                  );
                },
              ),
            ),
            if (selected.isNotEmpty)
              _SelectionBar(settings: s, actions: actions, count: selected.length, onClear: onClear)
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: s.background,
                  border: Border(top: BorderSide(color: s.text.withValues(alpha: 0.12))),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    TextButton.icon(
                      onPressed: onPrev,
                      icon: Icon(Icons.chevron_left, color: s.accent),
                      label: Text(onPrev == null ? '' : 'Chapter ${chapter.chapter - 1}', style: TextStyle(color: s.text)),
                    ),
                    TextButton.icon(
                      onPressed: onNext,
                      iconAlignment: IconAlignment.end,
                      icon: Icon(Icons.chevron_right, color: s.accent),
                      label: Text(onNext == null ? '' : 'Chapter ${chapter.chapter + 1}', style: TextStyle(color: s.text)),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  void _showChapterNotes(BuildContext context, WidgetRef ref, List<VerseNote> notes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.navySurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 16, 16, 20), children: [
            Text('Notes in ${chapter.book} ${chapter.chapter}',
                style: const TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            for (final n in notes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_note_rounded, color: AppTheme.goldDark),
                title: Text('${n.bookName} ${n.chapter}:${n.verse}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(n.content, maxLines: 3, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.pop(sheet);
                  showVerseNoteSheet(context, ref, n);
                },
              ),
          ]),
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  final ReaderSettings settings;
  final _SelectionActions actions;
  final int count;
  final VoidCallback onClear;
  const _SelectionBar({required this.settings, required this.actions, required this.count, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final s = settings;
    Widget btn(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: AppTheme.goldDark, size: 22),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                        fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ]),
            ),
          ),
        );

    final allMarked = actions.verses.isNotEmpty && actions.verses.every((v) => actions.bookmarkOf(v.verse) != null);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        border: Border(top: BorderSide(color: s.accent.withValues(alpha: 0.5))),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 0),
            child: Row(children: [
              Expanded(
                child: Text(
                  '$count verse${count == 1 ? '' : 's'} selected  ·  tap more, long-press to select a range',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
              IconButton(
                tooltip: 'Clear selection',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, size: 20, color: AppTheme.textSecondary),
                onPressed: onClear,
              ),
            ]),
          ),
          Row(children: [
            btn(allMarked ? Icons.bookmark_remove_outlined : Icons.bookmark_outline, allMarked ? 'Unmark' : 'Bookmark',
                actions.bookmark),
            btn(Icons.border_color_outlined, 'Highlight', actions.highlight),
            btn(Icons.edit_note_rounded, 'Note', actions.note),
            btn(Icons.copy_rounded, 'Copy', actions.copy),
          ]),
        ]),
      ),
    );
  }
}

class _VerseTile extends StatelessWidget {
  final BibleVerse verse;
  final ReaderSettings settings;
  final Highlight? highlight;
  final Bookmark? bookmark;
  final VerseNote? note;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onNoteTap;

  const _VerseTile({
    required this.verse,
    required this.settings,
    required this.highlight,
    required this.bookmark,
    required this.note,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onNoteTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final hl = highlight == null ? null : kHighlightColors[highlight!.color];
    final hlColor = hl == null ? null : (s.dark ? hl.withValues(alpha: 0.28) : hl.withValues(alpha: 0.65));

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? s.accent.withValues(alpha: 0.18) : (hlColor ?? Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: s.accent.withValues(alpha: 0.7), width: 1.5) : null,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (s.showVerseNumbers)
            SizedBox(
              width: 26,
              child: Text('${verse.verse}',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      color: s.accent,
                      fontSize: (s.fontSize * 0.75).clamp(11, 20),
                      fontWeight: FontWeight.bold)),
            ),
          Expanded(
            child: Text(verse.text,
                style: TextStyle(fontFamily: s.fontFamily, fontSize: s.fontSize, color: s.text, height: s.lineHeight)),
          ),
          if (bookmark != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Icon(Icons.bookmark, size: 16, color: s.accent),
            ),
          if (note != null)
            GestureDetector(
              onTap: onNoteTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 0, bottom: 4, right: 2),
                child: Icon(Icons.sticky_note_2, size: 18, color: s.accent),
              ),
            ),
        ]),
      ),
    );
  }
}

/// What the buttons on the selection bar do to ALL the selected verses.
class _SelectionActions {
  final BuildContext context;
  final WidgetRef ref;
  final BibleChapter chapter;
  final List<BibleVerse> verses; // selected, in reading order
  final Highlight? Function(int) highlightOf;
  final Bookmark? Function(int) bookmarkOf;
  final VerseNote? Function(int) noteOf;
  final VoidCallback onDone;

  _SelectionActions({
    required this.context,
    required this.ref,
    required this.chapter,
    required this.verses,
    required this.highlightOf,
    required this.bookmarkOf,
    required this.noteOf,
    required this.onDone,
  });

  /// "John 3:16", "John 3:16–18" or "John 3:16, 18, 20".
  String get label {
    if (verses.isEmpty) return chapter.book;
    final nums = [for (final v in verses) v.verse];
    final contiguous = nums.last - nums.first == nums.length - 1;
    if (nums.length == 1) return '${chapter.book} ${chapter.chapter}:${nums.first}';
    if (contiguous) return '${chapter.book} ${chapter.chapter}:${nums.first}–${nums.last}';
    return '${chapter.book} ${chapter.chapter}:${nums.join(', ')}';
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<int?> _bookId() async {
    final books = await ref.read(booksProvider.future);
    for (final b in books) {
      if (b.name == chapter.book) return b.id;
    }
    return null;
  }

  Future<void> copy() async {
    final text = verses.map((v) => '${v.verse}. ${v.text}').join('\n');
    await Clipboard.setData(ClipboardData(text: '$label\n$text'));
    _snack(verses.length == 1 ? 'Verse copied' : '${verses.length} verses copied');
    onDone();
  }

  Future<void> bookmark() async {
    final repo = ref.read(bibleRepositoryProvider);
    final allMarked = verses.every((v) => bookmarkOf(v.verse) != null);
    var failed = 0;
    try {
      if (allMarked) {
        for (final v in verses) {
          try {
            await repo.deleteBookmark(bookmarkOf(v.verse)!.id);
          } catch (_) {
            failed++;
          }
        }
      } else {
        final id = await _bookId();
        if (id == null) {
          _snack('Could not find "${chapter.book}" on the server.');
          return;
        }
        for (final v in verses.where((v) => bookmarkOf(v.verse) == null)) {
          try {
            await repo.createBookmark(bookId: id, chapter: v.chapter, verse: v.verse);
          } catch (_) {
            failed++;
          }
        }
      }
    } finally {
      ref.invalidate(bookmarksProvider);
    }
    _snack(failed > 0
        ? '$failed could not be saved. Check your connection.'
        : allMarked
            ? 'Bookmarks removed'
            : (verses.length == 1 ? 'Verse bookmarked' : '${verses.length} verses bookmarked'));
    onDone();
  }

  void highlight() {
    final anyHighlighted = verses.any((v) => highlightOf(v.verse) != null);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navySurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Highlight $label',
                style: const TextStyle(fontFamily: 'Lora', fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Wrap(spacing: 14, runSpacing: 10, children: [
              for (final e in kHighlightColors.entries)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(sheet);
                    _setHighlight(e.key);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: e.value,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                ),
              if (anyHighlighted)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(sheet);
                    _removeHighlights();
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.navyOutline)),
                    child: Icon(Icons.format_color_reset, size: 20, color: AppTheme.textSecondary),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _setHighlight(String color) async {
    final repo = ref.read(bibleRepositoryProvider);
    var failed = 0;
    try {
      final id = await _bookId();
      if (id == null) {
        _snack('Could not find "${chapter.book}" on the server.');
        return;
      }
      for (final v in verses) {
        try {
          final existing = highlightOf(v.verse);
          if (existing != null) {
            await repo.updateHighlight(existing.id, color: color);
          } else {
            await repo.createHighlight(bookId: id, chapter: v.chapter, verse: v.verse, color: color);
          }
        } catch (_) {
          failed++;
        }
      }
    } finally {
      ref.invalidate(highlightsProvider);
    }
    if (failed > 0) _snack('$failed could not be saved. Check your connection.');
    onDone();
  }

  Future<void> _removeHighlights() async {
    final repo = ref.read(bibleRepositoryProvider);
    for (final v in verses) {
      final h = highlightOf(v.verse);
      if (h == null) continue;
      try {
        await repo.deleteHighlight(h.id);
      } catch (_) {}
    }
    ref.invalidate(highlightsProvider);
    onDone();
  }

  /// One note for the whole selection. It is stored on the FIRST selected verse
  /// (the server keeps one note per verse) and starts with the range it covers.
  Future<void> note() async {
    if (verses.isEmpty) return;
    final first = verses.first;
    final existing = noteOf(first.verse);
    final saved = await showNoteEditor(
      context,
      ref,
      title: 'Note on $label',
      initial: existing?.content ?? '',
      hint: 'What is God showing you in ${verses.length == 1 ? 'this verse' : 'these verses'}?',
    );
    if (saved == null || saved.isEmpty) return;
    try {
      final repo = ref.read(bibleRepositoryProvider);
      if (existing != null) {
        await repo.updateNote(existing.id, saved);
      } else {
        final id = await _bookId();
        if (id == null) {
          _snack('Could not find "${chapter.book}" on the server.');
          return;
        }
        final content = verses.length > 1 ? '[$label]\n$saved' : saved;
        await repo.createNote(bookId: id, chapter: first.chapter, verse: first.verse, content: content);
      }
      ref.invalidate(verseNotesProvider);
      _snack('Note saved — tap the note icon on the verse to read it');
      onDone();
    } catch (e) {
      _snack(friendlyError(e));
    }
  }
}

/// Text box for writing / editing a note. Returns the text, or null if cancelled.
Future<String?> showNoteEditor(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  String initial = '',
  String hint = 'Write your note',
}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      backgroundColor: AppTheme.navySurface,
      title: Text(title, style: const TextStyle(fontSize: 17)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 8,
        minLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(d, ctrl.text.trim()), child: const Text('Save')),
      ],
    ),
  );
}

/// Read a saved note, with Edit / Delete (and optionally "Go to verse").
Future<void> showVerseNoteSheet(BuildContext context, WidgetRef ref, VerseNote note, {VoidCallback? onOpenVerse}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.navySurface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Icon(Icons.sticky_note_2, color: AppTheme.goldDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${note.bookName} ${note.chapter}:${note.verse}',
                    style: const TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 12),
            SelectableText(note.content, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, height: 1.6)),
            const SizedBox(height: 18),
            Row(children: [
              if (onOpenVerse != null)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheet);
                    onOpenVerse();
                  },
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Go to verse'),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(sheet);
                  final text = await showNoteEditor(context, ref,
                      title: 'Edit note', initial: note.content);
                  if (text == null || text.isEmpty) return;
                  try {
                    await ref.read(bibleRepositoryProvider).updateNote(note.id, text);
                    ref.invalidate(verseNotesProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                    }
                  }
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(sheet);
                  try {
                    await ref.read(bibleRepositoryProvider).deleteNote(note.id);
                    ref.invalidate(verseNotesProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                label: const Text('Delete', style: TextStyle(color: AppTheme.danger)),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
}
