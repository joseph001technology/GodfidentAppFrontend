import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/bible_provider.dart';
import '../../widgets/common/app_widgets.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final translation = ref.watch(selectedTranslationProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Search the Bible...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _ctrl.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                    })
                : null,
          ),
          onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(translation,
                  style: const TextStyle(color: AppTheme.gold, fontSize: 12)),
            ),
          ),
        ],
      ),
      body: results.when(
        loading: () => const ShimmerList(count: 6),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (verses) {
          if (_ctrl.text.isEmpty) {
            return const EmptyView(
              icon: Icons.search,
              title: 'Search the Bible',
              subtitle: 'Enter a word or phrase to find verses',
            );
          }
          if (verses.isEmpty) {
            return EmptyView(
              icon: Icons.find_in_page_outlined,
              title: 'No results',
              subtitle: 'No verses found for "${_ctrl.text}"',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: verses.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppTheme.navyOutline),
            itemBuilder: (_, i) {
              final v = verses[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                title: Text(v.reference,
                    style: const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(v.text,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ),
                onTap: () => context.push(
                    '/bible/verse?book=${Uri.encodeComponent(v.bookName)}&chapter=${v.chapter}&verse=${v.verse}&translation=${v.translationCode}'),
              );
            },
          );
        },
      ),
    );
  }
}
