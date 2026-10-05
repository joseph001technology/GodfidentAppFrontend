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

  const ChapterScreen({
    super.key,
    required this.book,
    required this.chapter,
    required this.translation,
    this.focusVerse,
  });

  @override
  ConsumerState<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends ConsumerState<ChapterScreen> {
  Timer? _logTimer;
  bool _logged = false;
  int? _selectedVerse;
  final _scroll = ScrollController();
  bool _jumped = false;

  @override
  void initState() {
    super.initState();
    _selectedVerse = widget.focusVerse;
    _logTimer = Timer(const Duration(seconds: 10), _logReading);
    // "Continue reading" on the Bible page starts from here.
    ReadingPositionStore.save(widget.book, widget.chapter, widget.translation);
  }

  @override
  void dispose() {
    _logTimer?.cancel();
    _scroll.dispose();
    super.dispose();
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
        _jumpToFocusVerse(chapter, s);
        return _ChapterView(
          scroll: _scroll,
          chapter: chapter,
          settings: s,
          selectedVerse: _selectedVerse,
          onVerseSelected: (v) => setState(() => _selectedVerse = _selectedVerse == v ? null : v),
          onPrev: chapter.hasPrevious ? () => _go(chapter, -1) : null,
          onNext: chapter.hasNext ? () => _go(chapter, 1) : null,
        );
      },
    );
  }

  /// Opened from a search result / bookmark: scroll roughly to that verse.
  void _jumpToFocusVerse(BibleChapter chapter, ReaderSettings s) {
    final v = widget.focusVerse;
    if (_jumped || v == null || v <= 1) return;
    _jumped = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final idx = chapter.verses.indexWhere((x) => x.verse == v);
      if (idx <= 0) return;
      final avg = s.fontSize * s.lineHeight * 2.6 + 16;
      _scroll.jumpTo((idx * avg).clamp(0, _scroll.position.maxScrollExtent).toDouble());
    });
  }
}

class _ChapterView extends ConsumerWidget {
  final ScrollController scroll;
  final BibleChapter chapter;
  final ReaderSettings settings;
  final int? selectedVerse;
  final ValueChanged<int> onVerseSelected;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _ChapterView({
    required this.scroll,
    required this.chapter,
    required this.settings,
    required this.selectedVerse,
    required this.onVerseSelected,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = settings;
    final highlights = ref.watch(highlightsProvider).valueOrNull ?? const <Highlight>[];
    final bookmarks = ref.watch(bookmarksProvider).valueOrNull ?? const <Bookmark>[];

    Highlight? highlightOf(int v) {
      for (final h in highlights) {
        if (h.bookName == chapter.book && h.chapter == chapter.chapter && h.verse == v) return h;
      }
      return null;
    }

    Bookmark? bookmarkOf(int v) {
      for (final b in bookmarks) {
        if (b.bookName == chapter.book && b.chapter == chapter.chapter && b.verse == v) return b;
      }
      return null;
    }

    return Scaffold(
      backgroundColor: s.background,
      appBar: AppBar(
        backgroundColor: s.background,
        foregroundColor: s.text,
        elevation: 0,
        iconTheme: IconThemeData(color: s.text),
        title: InkWell(
          onTap: () => context.go('/bible'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(chapter.book,
                style: TextStyle(fontFamily: 'Lora', fontSize: 20, fontWeight: FontWeight.bold, color: s.text)),
            Text('Chapter ${chapter.chapter} · ${chapter.translation}',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: s.text.withValues(alpha: 0.6))),
          ]),
        ),
        actions: [
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
                return _VerseTile(
                  verse: v,
                  book: chapter.book,
                  settings: s,
                  highlight: highlightOf(v.verse),
                  bookmark: bookmarkOf(v.verse),
                  isSelected: selectedVerse == v.verse,
                  onTap: () => onVerseSelected(v.verse),
                );
              },
            ),
          ),
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
    );
  }
}

class _VerseTile extends ConsumerWidget {
  final BibleVerse verse;
  final String book;
  final ReaderSettings settings;
  final Highlight? highlight;
  final Bookmark? bookmark;
  final bool isSelected;
  final VoidCallback onTap;

  const _VerseTile({
    required this.verse,
    required this.book,
    required this.settings,
    required this.highlight,
    required this.bookmark,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = settings;
    final hl = highlight == null ? null : kHighlightColors[highlight!.color];
    final hlColor = hl == null ? null : (s.dark ? hl.withValues(alpha: 0.28) : hl.withValues(alpha: 0.65));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: hlColor ?? (isSelected ? s.accent.withValues(alpha: 0.12) : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: s.accent.withValues(alpha: 0.6)) : null,
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
                  style: TextStyle(
                      fontFamily: s.fontFamily, fontSize: s.fontSize, color: s.text, height: s.lineHeight)),
            ),
            if (bookmark != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Icon(Icons.bookmark, size: 16, color: s.accent),
              ),
          ]),
        ),
      ),
      if (isSelected) _toolbar(context, ref),
    ]);
  }

  Widget _toolbar(BuildContext context, WidgetRef ref) {
    final s = settings;
    Widget btn(IconData icon, String label, VoidCallback onTap) => InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: AppTheme.goldDark, size: 20),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
            ]),
          ),
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 2, 8, 10),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: s.accent.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        btn(bookmark == null ? Icons.bookmark_outline : Icons.bookmark_remove_outlined,
            bookmark == null ? 'Bookmark' : 'Unmark', () => _toggleBookmark(context, ref)),
        btn(Icons.border_color_outlined, 'Highlight', () => _showHighlightPicker(context, ref)),
        btn(Icons.edit_note_rounded, 'Note', () => _addNote(context, ref)),
        btn(Icons.copy_rounded, 'Copy', () {
          Clipboard.setData(ClipboardData(text: '${verse.reference} — ${verse.text}'));
          _snack(ScaffoldMessenger.of(context), 'Verse copied');
        }),
      ]),
    );
  }

  void _snack(ScaffoldMessengerState m, String text) =>
      m.showSnackBar(SnackBar(content: Text(text)));

  Future<int?> _bookId(WidgetRef ref) async {
    final books = await ref.read(booksProvider.future);
    for (final b in books) {
      if (b.name == book) return b.id;
    }
    return null;
  }

  Future<void> _toggleBookmark(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(bibleRepositoryProvider);
      if (bookmark != null) {
        await repo.deleteBookmark(bookmark!.id);
        ref.invalidate(bookmarksProvider);
        _snack(messenger, 'Bookmark removed');
        return;
      }
      final id = await _bookId(ref);
      if (id == null) {
        _snack(messenger, 'Could not find "$book" on the server.');
        return;
      }
      await repo.createBookmark(bookId: id, chapter: verse.chapter, verse: verse.verse);
      ref.invalidate(bookmarksProvider);
      _snack(messenger, 'Verse bookmarked');
    } catch (e) {
      ref.invalidate(bookmarksProvider);
      _snack(messenger, friendlyError(e));
    }
  }

  void _showHighlightPicker(BuildContext context, WidgetRef ref) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navySurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Highlight ${verse.reference}',
                style: const TextStyle(fontFamily: 'Lora', fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Wrap(spacing: 14, runSpacing: 10, children: [
              for (final e in kHighlightColors.entries)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(sheet);
                    _setHighlight(messenger, ref, e.key);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: e.value,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: highlight?.color == e.key ? AppTheme.inkNavy : Colors.black12,
                          width: highlight?.color == e.key ? 3 : 1),
                    ),
                  ),
                ),
              if (highlight != null)
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(sheet);
                    try {
                      await ref.read(bibleRepositoryProvider).deleteHighlight(highlight!.id);
                      ref.invalidate(highlightsProvider);
                    } catch (e) {
                      _snack(messenger, friendlyError(e));
                    }
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.navyOutline)),
                    child: const Icon(Icons.format_color_reset, size: 20, color: AppTheme.textSecondary),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _setHighlight(ScaffoldMessengerState messenger, WidgetRef ref, String color) async {
    try {
      final repo = ref.read(bibleRepositoryProvider);
      if (highlight != null) {
        await repo.updateHighlight(highlight!.id, color: color);
      } else {
        final id = await _bookId(ref);
        if (id == null) {
          _snack(messenger, 'Could not find "$book" on the server.');
          return;
        }
        await repo.createHighlight(bookId: id, chapter: verse.chapter, verse: verse.verse, color: color);
      }
      ref.invalidate(highlightsProvider);
    } catch (e) {
      ref.invalidate(highlightsProvider);
      _snack(messenger, friendlyError(e));
    }
  }

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppTheme.navySurface,
        title: Text('Note on ${verse.reference}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 5,
          minLines: 3,
          decoration: const InputDecoration(hintText: 'What is God showing you in this verse?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(d, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    try {
      final id = await _bookId(ref);
      if (id == null) {
        _snack(messenger, 'Could not find "$book" on the server.');
        return;
      }
      await ref.read(bibleRepositoryProvider).createNote(
          bookId: id, chapter: verse.chapter, verse: verse.verse, content: text);
      ref.invalidate(verseNotesProvider);
      _snack(messenger, 'Note saved');
    } catch (e) {
      _snack(messenger, friendlyError(e));
    }
  }
}