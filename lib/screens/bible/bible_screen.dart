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

class _BibleScreenState extends ConsumerState<BibleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bible'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/bible/search'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.gold,
          labelColor: AppTheme.gold,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Old Testament'),
            Tab(text: 'New Testament'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _BookList(testament: 'OT'),
          _BookList(testament: 'NT'),
        ],
      ),
    );
  }
}

class _BookList extends ConsumerWidget {
  final String testament;
  const _BookList({required this.testament});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = testament == 'OT'
        ? ref.watch(otBooksProvider)
        : ref.watch(ntBooksProvider);

    return booksAsync.when(
      loading: () => const ShimmerList(count: 12),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => testament == 'OT'
            ? ref.invalidate(otBooksProvider)
            : ref.invalidate(ntBooksProvider),
      ),
      data: (books) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: books.length,
        itemBuilder: (_, i) => _BookTile(book: books[i]),
      ),
    );
  }
}

class _BookTile extends ConsumerWidget {
  final BibleBook book;
  const _BookTile({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.navyVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          '${book.number}',
          style: const TextStyle(
              color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(book.name, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text('${book.chapterCount} chapters',
          style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () => _showChapterPicker(context, ref, book),
    );
  }

  void _showChapterPicker(BuildContext context, WidgetRef ref, BibleBook book) {
    final translation = ref.read(selectedTranslationProvider);
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
            Row(children: [
              Text(book.name, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Text('$translation',
                  style: const TextStyle(color: AppTheme.gold, fontSize: 13)),
            ]),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
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
                          '/bible/chapter?book=${Uri.encodeComponent(book.name)}&chapter=$ch&translation=$translation');
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.navyVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.navyOutline, width: 0.5),
                      ),
                      alignment: Alignment.center,
                      child: Text('$ch',
                          style: const TextStyle(color: AppTheme.gold, fontSize: 13)),
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
