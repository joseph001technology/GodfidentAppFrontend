import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/bible.dart';
import '../../providers/bible_provider.dart';
import '../../services/reader_settings.dart';
import '../../widgets/common/app_widgets.dart';
import 'reader_settings_sheet.dart';

class BibleScreen extends ConsumerStatefulWidget {
  /// `/bible?browse=1` shows the list of books; plain `/bible` takes you back
  /// to the chapter (and verse) you were reading last time.
  final bool browse;
  const BibleScreen({super.key, this.browse = false});

  @override
  ConsumerState<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends ConsumerState<BibleScreen> {
  int _selectedTestament = 0; // 0: Old Testament, 1: New Testament
  String? _selectedBookName;
  ReadingPosition? _last;
  late bool _checking = !widget.browse; // true until we know whether to jump to the last place

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  Future<void> _loadLast() async {
    final p = await ReadingPositionStore.load();
    if (!mounted) return;
    setState(() {
      _last = p;
      _checking = false;
    });
    if (p != null && !widget.browse) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.push('/bible/chapter?book=${Uri.encodeComponent(p.book)}&chapter=${p.chapter}'
            '&translation=${p.translation}&verse=${p.verse}&resume=1');
      });
    }
  }

  void _showMenu(BuildContext context) {
    final translation = ref.read(selectedTranslationProvider);
    Widget item(IconData icon, String title, String sub, VoidCallback onTap) => ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppTheme.navyVariant, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppTheme.goldDark, size: 22),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: sub.isEmpty ? null : Text(sub, style: const TextStyle(fontSize: 12)),
          onTap: onTap,
        );

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navySurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 10, bottom: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_last != null)
              item(Icons.play_circle_outline, 'Continue reading', '${_last!.book} ${_last!.chapter}', () {
                Navigator.pop(sheet);
                context.push(
                    '/bible/chapter?book=${Uri.encodeComponent(_last!.book)}&chapter=${_last!.chapter}&translation=${_last!.translation}&verse=${_last!.verse}&resume=1');
              }),
            item(Icons.translate_rounded, 'Translation', translation, () {
              Navigator.pop(sheet);
              _pickTranslation(context);
            }),
            item(Icons.text_fields_rounded, 'Text size and theme', 'Font, spacing, paper / sepia / night', () {
              Navigator.pop(sheet);
              showReaderSettingsSheet(context);
            }),
            item(Icons.bookmark_outline, 'Bookmarks', 'Verses you saved', () {
              Navigator.pop(sheet);
              context.push('/bible/library?tab=0');
            }),
            item(Icons.border_color_outlined, 'Highlights', 'Verses you coloured', () {
              Navigator.pop(sheet);
              context.push('/bible/library?tab=1');
            }),
            item(Icons.edit_note_rounded, 'Verse notes', 'What you wrote while reading', () {
              Navigator.pop(sheet);
              context.push('/bible/library?tab=2');
            }),
            item(Icons.calendar_month_outlined, 'Reading plans', 'Read the Bible in order', () {
              Navigator.pop(sheet);
              context.push('/more/plans');
            }),
            item(Icons.auto_stories_outlined, 'Devotionals', 'Daily reflections', () {
              Navigator.pop(sheet);
              context.push('/more/devotionals');
            }),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickTranslation(BuildContext context) async {
    List<BibleTranslation> list = const [];
    try {
      list = await ref.read(translationsProvider.future);
    } catch (_) {}
    if (!context.mounted) return;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Translations could not be loaded. Check your connection.')));
      return;
    }
    final current = ref.read(selectedTranslationProvider);
    final picked = await showDialog<String>(
      context: context,
      builder: (d) => SimpleDialog(
        backgroundColor: AppTheme.navySurface,
        title: const Text('Choose translation'),
        children: [
          for (final t in list)
            ListTile(
              title: Text(t.code, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(t.fullName.isNotEmpty ? t.fullName : t.name),
              trailing: t.code == current ? const Icon(Icons.check, color: AppTheme.goldDark) : null,
              onTap: () => Navigator.pop(d, t.code),
            ),
        ],
      ),
    );
    if (picked != null) ref.read(selectedTranslationProvider.notifier).state = picked;
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(backgroundColor: AppTheme.navy, body: Center(child: CircularProgressIndicator(color: AppTheme.gold)));
    }
    final otAsync = ref.watch(otBooksProvider);
    final ntAsync = ref.watch(ntBooksProvider);
    final verseAsync = ref.watch(verseOfTheDayProvider);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Text('📖 ', style: TextStyle(fontSize: 20)),
            Text(
              'Holy Bible',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: AppTheme.textPrimary),
            onPressed: () => context.push('/bible/search'),
          ),
          IconButton(
            icon: Icon(Icons.menu, color: AppTheme.textPrimary),
            tooltip: 'Bible menu',
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verse of the Day Banner — stays a dark navy gradient card on
            // purpose (matches the prototype's verse card), so its text
            // uses textOnDark/textOnDarkMuted, not the page's textPrimary.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: Gradients.verseOfDay, // was inline Color(0xFF1A1040)->Color(0xFF2D1B69)
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('✦ ', style: TextStyle(color: AppTheme.gold, fontSize: 12)),
                      Text(
                        'VERSE OF THE DAY',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.gold.withValues(alpha: 0.9),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  verseAsync.when(
                    data: (v) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '"${v.text}"',
                          style: const TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.textOnDark, // was textPrimary
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '— ${v.reference}',
                          style: const TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.gold,
                          ),
                        ),
                      ],
                    ),
                    loading: () => const LoadingShimmer(height: 40),
                    error: (e, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verse of the day could not be loaded. ${friendlyError(e)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textOnDarkMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: () => ref.invalidate(verseOfTheDayProvider),
                          icon: const Icon(Icons.refresh, size: 16, color: AppTheme.gold),
                          label: const Text('Retry', style: TextStyle(color: AppTheme.gold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_last != null) ...[
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push(
                    '/bible/chapter?book=${Uri.encodeComponent(_last!.book)}&chapter=${_last!.chapter}&translation=${_last!.translation}&verse=${_last!.verse}&resume=1'),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.navyOutline),
                  ),
                  child: Row(children: [
                    const Icon(Icons.play_circle_fill_rounded, color: AppTheme.goldDark, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Continue reading', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        Text('${_last!.book} ${_last!.chapter}',
                            style: const TextStyle(fontFamily: 'Lora', fontSize: 17, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  ]),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Old / New Testament Tabs
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTestament = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTestament == 0 ? AppTheme.gold : AppTheme.navyVariant,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedTestament == 0 ? AppTheme.gold : AppTheme.navyOutline,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('📜 ', style: TextStyle(fontSize: 14)),
                          Text(
                            'Old Testament',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              // was AppTheme.navy — that token is now the
                              // page background color (ivory), which would
                              // be nearly invisible on a gold chip. Active
                              // "text on gold" needs the dedicated ink token.
                              color: _selectedTestament == 0 ? AppTheme.inkNavy : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTestament = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTestament == 1 ? AppTheme.gold : AppTheme.navyVariant,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedTestament == 1 ? AppTheme.gold : AppTheme.navyOutline,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('✝️ ', style: TextStyle(fontSize: 14)),
                          Text(
                            'New Testament',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              // same fix as above
                              color: _selectedTestament == 1 ? AppTheme.inkNavy : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Book Grid
            _selectedTestament == 0
                ? _buildBooksGrid(otAsync)
                : _buildBooksGrid(ntAsync),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildBooksGrid(AsyncValue<List<BibleBook>> booksAsync) {
    return booksAsync.when(
      loading: () => const LoadingShimmer(height: 300),
      error: (e, _) => ErrorView(
        message: friendlyError(e),
        onRetry: () {
          ref.invalidate(otBooksProvider);
          ref.invalidate(ntBooksProvider);
        },
      ),
      data: (books) {
        if (books.isEmpty) {
          return ErrorView(
            message: 'The server has no Bible books yet. The Bible has not been loaded on the server - '
                'it needs to be imported there (not a problem with your phone).',
            onRetry: () {
              ref.invalidate(otBooksProvider);
              ref.invalidate(ntBooksProvider);
            },
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: books.length,
          itemBuilder: (context, i) {
            final book = books[i];
            final isSelected = _selectedBookName == book.name;

            return GestureDetector(
              onTap: () {
                setState(() => _selectedBookName = book.name);
                _showChapterPicker(context, book);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.gold.withValues(alpha: 0.16) : AppTheme.navyVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    // was Colors.white.withOpacity(0.08) — invisible on a
                    // light chip
                    color: isSelected ? AppTheme.gold : AppTheme.navyOutline,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  book.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    // was AppTheme.gold — gold-on-pale-gold-tint is low
                    // contrast on a light card; goldDark reads clearly
                    color: isSelected ? AppTheme.goldDark : AppTheme.textPrimary,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showChapterPicker(BuildContext context, BibleBook book) {
    final translation = ref.read(selectedTranslationProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navySurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  book.name,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    translation,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.goldDark, // was gold — same low-contrast fix
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Select Chapter (1 - ${book.chapterCount})',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: book.chapterCount,
                itemBuilder: (_, i) {
                  final ch = i + 1;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      context.push(
                        '/bible/chapter?book=${Uri.encodeComponent(book.name)}&chapter=$ch&translation=$translation',
                      ).then((_) => _loadLast());
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.navyVariant,
                        borderRadius: BorderRadius.circular(10),
                        // was Colors.white.withOpacity(0.1) — invisible on
                        // a light chip
                        border: Border.all(color: AppTheme.navyOutline),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$ch',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.goldDark, // was gold
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
