import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/bible_books.dart';
import '../../core/theme.dart';
import '../../models/bible.dart';
import '../../providers/bible_provider.dart';
import '../../widgets/common/app_widgets.dart';
import 'chapter_picker.dart';

/// Bible search. Typing a book name ("jo", "1 cor", "psalm 23", "john 3:16")
/// lists the matching BOOKS first, instantly and offline; the verses whose
/// words match come after, from the server.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _text = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _text = v.trim());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) ref.read(searchQueryProvider.notifier).state = _text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final translation = ref.watch(selectedTranslationProvider);
    final matches = BibleBooks.parse(_text);
    final directRef = matches.isNotEmpty && matches.first.hasChapter;
    // Only look up verse TEXT when it is not a pure reference like "John 3".
    final wantVerses = _text.length >= 2 && !directRef;
    final AsyncValue<List<BibleVerse>> results =
        wantVerses ? ref.watch(searchResultsProvider) : const AsyncValue<List<BibleVerse>>.data([]);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Book, verse or word  (e.g. John 3:16)',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            suffixIcon: _text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _ctrl.clear();
                      _onChanged('');
                    })
                : null,
          ),
          onChanged: _onChanged,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text(translation, style: const TextStyle(color: AppTheme.goldDark, fontSize: 12, fontWeight: FontWeight.w700))),
          ),
        ],
      ),
      body: _text.isEmpty
          ? const EmptyView(
              icon: Icons.search,
              title: 'Search the Bible',
              subtitle: 'Type a book name, a reference like "Psalm 23", or any word.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                if (matches.isNotEmpty) ...[
                  _header('BOOKS'),
                  for (final m in matches.take(12))
                    _bookTile(context, m, translation),
                ],
                if (wantVerses) ...[
                  _header('VERSES'),
                  results.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator(color: AppTheme.gold)),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(friendlyError(e), style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                    data: (verses) {
                      if (verses.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            matches.isEmpty ? 'No verses found for "$_text".' : 'No verses contain "$_text".',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        );
                      }
                      return Column(children: [
                        for (final v in verses)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            title: Text(v.reference,
                                style: const TextStyle(color: AppTheme.goldDark, fontSize: 13, fontWeight: FontWeight.w700)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(v.text, maxLines: 3, overflow: TextOverflow.ellipsis),
                            ),
                            onTap: () => openChapter(context, v.bookName, v.chapter, v.translationCode, verse: v.verse),
                          ),
                      ]);
                    },
                  ),
                ],
              ],
            ),
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppTheme.textMuted)),
      );

  Widget _bookTile(BuildContext context, BookMatch m, String translation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.navyOutline),
      ),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppTheme.navyVariant, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.menu_book_rounded, color: AppTheme.goldDark, size: 20),
        ),
        title: Text(m.label, style: const TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.bold)),
        subtitle: Text('${m.book.testament == 'OT' ? 'Old' : 'New'} Testament · ${m.book.chapters} chapters'),
        trailing: Icon(Icons.chevron_right, color: AppTheme.textMuted),
        onTap: () {
          if (m.hasChapter) {
            openChapter(context, m.book.name, m.chapter!, translation, verse: m.verse);
          } else {
            showChapterPickerFor(context, m.book, translation);
          }
        },
      ),
    );
  }
}
