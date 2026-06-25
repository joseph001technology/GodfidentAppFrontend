import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../core/theme.dart';
import '../../models/bible.dart';
import '../../providers/bible_provider.dart';
import '../../repositories/analytics_repository.dart';
import '../../repositories/bible_repository.dart';
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

  @override
  void initState() {
    super.initState();
    // Auto-log reading after 10 seconds on screen
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
        appBar: AppBar(title: Text('${widget.book} ${widget.chapter}')),
        body: const ShimmerList(count: 8),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text('${widget.book} ${widget.chapter}')),
        body: ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(chapterProvider(params)),
        ),
      ),
      data: (chapter) => _ChapterView(chapter: chapter),
    );
  }
}

class _ChapterView extends ConsumerWidget {
  final BibleChapter chapter;
  const _ChapterView({required this.chapter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translation = ref.watch(selectedTranslationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${chapter.book} ${chapter.chapter}'),
        actions: [
          // Translation chip
          GestureDetector(
            onTap: () => _showTranslationPicker(context, ref),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.gold, width: 0.8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(translation,
                  style: const TextStyle(color: AppTheme.gold, fontSize: 12)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: chapter.verses.length,
              itemBuilder: (_, i) => _VerseTile(
                verse: chapter.verses[i],
                book: chapter.book,
              ),
            ),
          ),
          // Prev / Next navigation
          _ChapterNav(chapter: chapter),
        ],
      ),
    );
  }

  void _showTranslationPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navySurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Translation',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...['KJV', 'NIV', 'ESV', 'NKJV', 'NLT'].map((t) => ListTile(
                  title: Text(t),
                  trailing: ref.read(selectedTranslationProvider) == t
                      ? const Icon(Icons.check, color: AppTheme.gold)
                      : null,
                  onTap: () {
                    ref.read(selectedTranslationProvider.notifier).state = t;
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

class _VerseTile extends ConsumerWidget {
  final BibleVerse verse;
  final String book;
  const _VerseTile({required this.verse, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onLongPress: () => _showVerseActions(context, ref),
      onTap: () => context.push(
          '/bible/verse?book=${Uri.encodeComponent(book)}&chapter=${verse.chapter}&verse=${verse.verse}&translation=${verse.translationCode}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${verse.verse} ',
                style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: verse.text,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(height: 1.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVerseActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navySurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${verse.reference}  —  ${verse.text}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic, color: Colors.grey),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.bookmark_border, color: AppTheme.gold),
              title: const Text('Bookmark'),
              onTap: () async {
                Navigator.pop(context);
                await _bookmark(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.highlight, color: Colors.yellow),
              title: const Text('Highlight'),
              onTap: () {
                Navigator.pop(context);
                _showHighlightPicker(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_add_outlined, color: Colors.blue),
              title: const Text('Add Note'),
              onTap: () {
                Navigator.pop(context);
                _showNoteDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: Colors.green),
              title: const Text('Explain with AI'),
              onTap: () {
                Navigator.pop(context);
                context.push(
                    '/ai/explain-verse?ref=${Uri.encodeComponent(verse.reference)}&text=${Uri.encodeComponent(verse.text)}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.grey),
              title: const Text('Copy'),
              onTap: () {
                Clipboard.setData(
                    ClipboardData(text: '${verse.reference} — ${verse.text}'));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Verse copied')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bookmark(BuildContext context, WidgetRef ref) async {
    try {
      // We need book ID — get from books list
      final books = await ref.read(bibleRepositoryProvider).getBooks();
      final bookObj = books.firstWhere((b) => b.name == book,
          orElse: () => books.first);
      await ref.read(bibleRepositoryProvider).createBookmark(
            bookId: bookObj.id,
            chapter: verse.chapter,
            verse: verse.verse,
          );
      ref.invalidate(bookmarksProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Bookmarked!')));
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
            'orange': Colors.orange,
          }
              .entries
              .map((e) => GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        final books =
                            await ref.read(bibleRepositoryProvider).getBooks();
                        final bookObj = books.firstWhere((b) => b.name == book,
                            orElse: () => books.first);
                        await ref
                            .read(bibleRepositoryProvider)
                            .createHighlight(
                              bookId: bookObj.id,
                              chapter: verse.chapter,
                              verse: verse.verse,
                              color: e.key,
                            );
                        ref.invalidate(highlightsProvider);
                      } catch (_) {}
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: e.value, shape: BoxShape.circle),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showNoteDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.navySurface,
        title: Text('Note on ${verse.reference}'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Write your note...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (controller.text.isNotEmpty) {
                try {
                  final books =
                      await ref.read(bibleRepositoryProvider).getBooks();
                  final bookObj = books.firstWhere((b) => b.name == book,
                      orElse: () => books.first);
                  await ref.read(bibleRepositoryProvider).createNote(
                        bookId: bookObj.id,
                        chapter: verse.chapter,
                        verse: verse.verse,
                        content: controller.text,
                      );
                  ref.invalidate(verseNotesProvider);
                } catch (_) {}
              }
            },
            child: const Text('Save'),
          ),
        ],
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
      decoration: const BoxDecoration(
        color: AppTheme.navySurface,
        border: Border(top: BorderSide(color: AppTheme.navyOutline, width: 0.5)),
      ),
      child: Row(
        children: [
          if (chapter.hasPrevious)
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.gold,
                    side: const BorderSide(color: AppTheme.navyOutline)),
                icon: const Icon(Icons.chevron_left, size: 18),
                label: Text('Ch ${chapter.chapter - 1}'),
                onPressed: () => context.pushReplacement(
                    '/bible/chapter?book=${Uri.encodeComponent(chapter.book)}&chapter=${chapter.chapter - 1}&translation=${chapter.translation}'),
              ),
            )
          else
            const Expanded(child: SizedBox()),
          const SizedBox(width: 12),
          if (chapter.hasNext)
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.gold,
                    side: const BorderSide(color: AppTheme.navyOutline)),
                label: Text('Ch ${chapter.chapter + 1}'),
                icon: const Icon(Icons.chevron_right, size: 18),
                onPressed: () => context.pushReplacement(
                    '/bible/chapter?book=${Uri.encodeComponent(chapter.book)}&chapter=${chapter.chapter + 1}&translation=${chapter.translation}'),
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}
