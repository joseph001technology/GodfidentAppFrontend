import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/bible.dart';
import '../../providers/bible_provider.dart';
import '../../widgets/common/app_widgets.dart';
import 'chapter_screen.dart' show kHighlightColors, showVerseNoteSheet;

/// Everything the person saved while reading: bookmarks, highlights, notes.
class BibleLibraryScreen extends ConsumerWidget {
  final int initialTab;
  const BibleLibraryScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translation = ref.watch(selectedTranslationProvider);

    void open(String book, int chapter, int verse) => context.push(
        '/bible/chapter?book=${Uri.encodeComponent(book)}&chapter=$chapter&translation=$translation&verse=$verse');

    return DefaultTabController(
      length: 3,
      initialIndex: initialTab.clamp(0, 2),
      child: Scaffold(
        backgroundColor: AppTheme.navy,
        appBar: AppBar(
          title: const Text('My Bible', style: TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            labelColor: AppTheme.goldDark,
            indicatorColor: AppTheme.gold,
            tabs: [Tab(text: 'Bookmarks'), Tab(text: 'Highlights'), Tab(text: 'Notes')],
          ),
        ),
        body: TabBarView(children: [
          _list<Bookmark>(
            ref.watch(bookmarksProvider),
            empty: 'No bookmarks yet. Tap a verse while reading and choose Bookmark.',
            onRefresh: () => ref.refresh(bookmarksProvider.future),
            builder: (b) => _Card(
              title: b.reference.isNotEmpty ? b.reference : '${b.bookName} ${b.chapter}:${b.verse}',
              subtitle: b.note,
              leading: const Icon(Icons.bookmark, color: AppTheme.goldDark),
              onTap: () => open(b.bookName, b.chapter, b.verse),
              onDelete: () async {
                await ref.read(bibleRepositoryProvider).deleteBookmark(b.id);
                ref.invalidate(bookmarksProvider);
              },
            ),
          ),
          _list<Highlight>(
            ref.watch(highlightsProvider),
            empty: 'No highlights yet. Tap a verse while reading and choose Highlight.',
            onRefresh: () => ref.refresh(highlightsProvider.future),
            builder: (h) => _Card(
              title: h.reference.isNotEmpty ? h.reference : '${h.bookName} ${h.chapter}:${h.verse}',
              subtitle: h.note,
              leading: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: kHighlightColors[h.color] ?? Colors.yellow, shape: BoxShape.circle),
              ),
              onTap: () => open(h.bookName, h.chapter, h.verse),
              onDelete: () async {
                await ref.read(bibleRepositoryProvider).deleteHighlight(h.id);
                ref.invalidate(highlightsProvider);
              },
            ),
          ),
          _list<VerseNote>(
            ref.watch(verseNotesProvider),
            empty: 'No verse notes yet. Tap a verse while reading and choose Note.',
            onRefresh: () => ref.refresh(verseNotesProvider.future),
            builder: (n) => _Card(
              title: '${n.bookName} ${n.chapter}:${n.verse}',
              subtitle: n.content,
              leading: const Icon(Icons.edit_note_rounded, color: AppTheme.goldDark),
              onTap: () => showVerseNoteSheet(context, ref, n, onOpenVerse: () => open(n.bookName, n.chapter, n.verse)),
              onDelete: () async {
                await ref.read(bibleRepositoryProvider).deleteNote(n.id);
                ref.invalidate(verseNotesProvider);
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _list<T>(
    AsyncValue<List<T>> async, {
    required String empty,
    required Future<dynamic> Function() onRefresh,
    required Widget Function(T) builder,
  }) {
    return async.when(
      loading: () => const ShimmerList(count: 5),
      error: (e, _) => ErrorView(message: friendlyError(e)),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(empty, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            itemCount: items.length,
            itemBuilder: (_, i) => builder(items[i]),
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget leading;
  final VoidCallback onTap;
  final Future<void> Function()? onDelete;
  const _Card({required this.title, required this.subtitle, required this.leading, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.navyOutline),
      ),
      child: ListTile(
        leading: leading,
        title: Text(title, style: const TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.bold)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
        onTap: onTap,
        trailing: onDelete == null
            ? Icon(Icons.chevron_right, color: AppTheme.textMuted)
            : IconButton(
                icon: Icon(Icons.delete_outline, color: AppTheme.textMuted),
                tooltip: 'Remove',
                onPressed: () async {
                  try {
                    await onDelete!();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                    }
                  }
                },
              ),
      ),
    );
  }
}
