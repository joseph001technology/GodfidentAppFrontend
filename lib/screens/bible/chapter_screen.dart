import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../core/theme.dart';
import '../../models/bible.dart';
import '../../providers/bible_provider.dart';
import '../../repositories/analytics_repository.dart';
import '../../widgets/common/app_widgets.dart';

class ChapterScreen extends ConsumerStatefulWidget {
  final String book;
  final int chapter;
  final String translation;

  const ChapterScreen({
    super.key,
    required this.book,
    required this.chapter,
    required this.translation,
  });

  @override
  ConsumerState<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends ConsumerState<ChapterScreen> {
  Timer? _logTimer;
  bool _logged = false;
  int? _selectedVerseNumber;

  @override
  void initState() {
    super.initState();
    _logTimer = Timer(const Duration(seconds: 10), _logReading);
  }

  @override
  void dispose() {
    _logTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final params = ChapterParams(widget.book, widget.chapter, widget.translation);
    final chapterAsync = ref.watch(chapterProvider(params));

    return chapterAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppTheme.navy,
        appBar: AppBar(title: Text('${widget.book} ${widget.chapter}')),
        body: const ShimmerList(count: 8),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppTheme.navy,
        appBar: AppBar(title: Text('${widget.book} ${widget.chapter}')),
        body: ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(chapterProvider(params)),
        ),
      ),
      data: (chapter) => _ChapterView(
        chapter: chapter,
        selectedVerse: _selectedVerseNumber,
        onVerseSelected: (v) {
          setState(() {
            _selectedVerseNumber = _selectedVerseNumber == v ? null : v;
          });
        },
      ),
    );
  }
}

class _ChapterView extends ConsumerWidget {
  final BibleChapter chapter;
  final int? selectedVerse;
  final ValueChanged<int> onVerseSelected;

  const _ChapterView({
    required this.chapter,
    required this.selectedVerse,
    required this.onVerseSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translation = ref.watch(selectedTranslationProvider);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chapter.book,
              style: const TextStyle(
                fontFamily: 'Lora',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'Chapter ${chapter.chapter}',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppTheme.gold),
                onPressed: chapter.hasPrevious
                    ? () => context.pushReplacement(
                          '/bible/chapter?book=${Uri.encodeComponent(chapter.book)}&chapter=${chapter.chapter - 1}&translation=$translation',
                        )
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppTheme.gold),
                onPressed: chapter.hasNext
                    ? () => context.pushReplacement(
                          '/bible/chapter?book=${Uri.encodeComponent(chapter.book)}&chapter=${chapter.chapter + 1}&translation=$translation',
                        )
                    : null,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: chapter.verses.length,
              itemBuilder: (_, i) {
                final v = chapter.verses[i];
                final isSelected = selectedVerse == v.verse;
                return _VerseTile(
                  verse: v,
                  book: chapter.book,
                  isSelected: isSelected,
                  onTap: () => onVerseSelected(v.verse),
                );
              },
            ),
          ),
          _ChapterNav(chapter: chapter),
        ],
      ),
    );
  }
}

class _VerseTile extends ConsumerWidget {
  final BibleVerse verse;
  final String book;
  final bool isSelected;
  final VoidCallback onTap;

  const _VerseTile({
    required this.verse,
    required this.book,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.gold.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${verse.verse}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: AppTheme.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    verse.text,
                    style: const TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                      height: 1.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isSelected) _buildVerseActionToolbar(context, ref),
      ],
    );
  }

  Widget _buildVerseActionToolbar(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(28, 4, 8, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.gold.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _toolbarButton(
            icon: Icons.bookmark_outline,
            label: 'Bookmark',
            onTap: () => _bookmark(context, ref),
          ),
          _toolbarButton(
            icon: Icons.create_outlined,
            label: 'Highlight',
            onTap: () => _showHighlightPicker(context, ref),
          ),
          _toolbarButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: () {
              Clipboard.setData(ClipboardData(text: '${verse.reference} — ${verse.text}'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Verse text copied to clipboard!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.gold, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bookmark(BuildContext context, WidgetRef ref) async {
    try {
      final books = await ref.read(bibleRepositoryProvider).getBooks();
      final bookObj = books.firstWhere((b) => b.name == book, orElse: () => books.first);
      await ref.read(bibleRepositoryProvider).createBookmark(
            bookId: bookObj.id,
            chapter: verse.chapter,
            verse: verse.verse,
          );
      ref.invalidate(bookmarksProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verse Bookmarked!')),
        );
      }
    } catch (_) {}
  }

  void _showHighlightPicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.navySurface,
        title: const Text('Choose Highlight Color'),
        content: Wrap(
          spacing: 12,
          children: {
            'yellow': Colors.yellow,
            'green': Colors.green,
            'blue': Colors.blue,
            'pink': Colors.pink,
            'purple': Colors.purple,
          }.entries.map((e) => GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final books = await ref.read(bibleRepositoryProvider).getBooks();
                    final bookObj = books.firstWhere((b) => b.name == book, orElse: () => books.first);
                    await ref.read(bibleRepositoryProvider).createHighlight(
                          bookId: bookObj.id,
                          chapter: verse.chapter,
                          verse: verse.verse,
                          color: e.key,
                        );
                    ref.invalidate(highlightsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Verse highlighted in ${e.key}!')),
                      );
                    }
                  } catch (_) {}
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: e.value, shape: BoxShape.circle),
                ),
              )).toList(),
        ),
      ),
    );
  }
}

class _ChapterNav extends StatelessWidget {
  final BibleChapter chapter;
  const _ChapterNav({required this.chapter});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (chapter.hasPrevious)
            TextButton.icon(
              icon: const Icon(Icons.chevron_left, color: AppTheme.gold),
              label: Text('Chapter ${chapter.chapter - 1}', style: const TextStyle(color: AppTheme.textPrimary)),
              onPressed: () => context.pushReplacement(
                '/bible/chapter?book=${Uri.encodeComponent(chapter.book)}&chapter=${chapter.chapter - 1}&translation=${chapter.translation}',
              ),
            )
          else
            const SizedBox(),
          if (chapter.hasNext)
            TextButton.icon(
              label: Text('Chapter ${chapter.chapter + 1}', style: const TextStyle(color: AppTheme.textPrimary)),
              icon: const Icon(Icons.chevron_right, color: AppTheme.gold),
              onPressed: () => context.pushReplacement(
                '/bible/chapter?book=${Uri.encodeComponent(chapter.book)}&chapter=${chapter.chapter + 1}&translation=${chapter.translation}',
              ),
            )
          else
            const SizedBox(),
        ],
      ),
    );
  }
}
