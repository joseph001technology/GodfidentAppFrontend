import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/bible.dart';
import '../../providers/bible_provider.dart';
import '../../widgets/common/app_widgets.dart';

class BibleScreen extends ConsumerStatefulWidget {
  const BibleScreen({super.key});

  @override
  ConsumerState<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends ConsumerState<BibleScreen> {
  int _selectedTestament = 0; // 0: Old Testament, 1: New Testament
  String? _selectedBookName = '1 Samuel';

  @override
  Widget build(BuildContext context) {
    final otAsync = ref.watch(otBooksProvider);
    final ntAsync = ref.watch(ntBooksProvider);
    final verseAsync = ref.watch(verseOfTheDayProvider);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
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
            icon: const Icon(Icons.search, color: AppTheme.textPrimary),
            onPressed: () => context.push('/bible/search'),
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: AppTheme.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verse of the Day Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A1040), Color(0xFF2D1B69)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.gold.withOpacity(0.3)),
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
                          color: AppTheme.gold.withOpacity(0.9),
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
                            color: AppTheme.textPrimary,
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
                    error: (_, __) => const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '"I can do all things through Christ who strengthens me."',
                          style: TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '— Philippians 4:13',
                          style: TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

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
                              color: _selectedTestament == 0 ? AppTheme.navy : AppTheme.textPrimary,
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
                              color: _selectedTestament == 1 ? AppTheme.navy : AppTheme.textPrimary,
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
      error: (e, _) => ErrorView(message: e.toString()),
      data: (books) {
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
                  color: isSelected ? AppTheme.gold.withOpacity(0.2) : AppTheme.navyVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppTheme.gold : Colors.white.withOpacity(0.08),
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
                    color: isSelected ? AppTheme.gold : AppTheme.textPrimary,
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
                  style: const TextStyle(
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
                    color: AppTheme.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    translation,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.gold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Select Chapter (1 - ${book.chapterCount})',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted),
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
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.navyVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$ch',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.gold,
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
