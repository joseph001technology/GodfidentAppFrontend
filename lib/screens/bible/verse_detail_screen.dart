import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme.dart';
import '../../providers/bible_provider.dart';
import '../../repositories/ai_repository.dart';
import '../../widgets/common/app_widgets.dart';

class VerseDetailScreen extends ConsumerStatefulWidget {
  final String book;
  final int chapter;
  final int verse;
  final String translation;

  const VerseDetailScreen({
    super.key,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.translation,
  });

  @override
  ConsumerState<VerseDetailScreen> createState() => _VerseDetailScreenState();
}

class _VerseDetailScreenState extends ConsumerState<VerseDetailScreen> {
  String? _explanation;
  bool _loadingAi = false;

  Future<void> _explain(String verseText) async {
    setState(() => _loadingAi = true);
    try {
      final result = await AiRepository().explainVerse(
        reference: '${widget.book} ${widget.chapter}:${widget.verse}',
        translation: widget.translation,
        verseText: verseText,
      );
      setState(() => _explanation = result);
    } catch (e) {
      setState(() => _explanation = 'Could not load explanation. Please try again.');
    } finally {
      setState(() => _loadingAi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verseRef = VerseRef(widget.book, widget.chapter, widget.verse);
    final crossRefsAsync = ref.watch(crossRefsProvider(verseRef));
    final params = ChapterParams(widget.book, widget.chapter, widget.translation);
    final chapterAsync = ref.watch(chapterProvider(params));

    final verseText = chapterAsync.value?.verses
        .firstWhere((v) => v.verse == widget.verse,
            orElse: () => chapterAsync.value!.verses.first)
        .text ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.book} ${widget.chapter}:${widget.verse}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'Parallel Translations',
            onPressed: () => context.push(
                '/bible/parallel?book=${Uri.encodeComponent(widget.book)}&chapter=${widget.chapter}&verse=${widget.verse}'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Verse reference badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.gold.withOpacity(0.3)),
            ),
            child: Text(
              '${widget.book} ${widget.chapter}:${widget.verse}  ·  ${widget.translation}',
              style: const TextStyle(color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),

          // Verse text
          chapterAsync.when(
            data: (_) => Text(verseText,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    height: 1.6, fontStyle: FontStyle.italic)),
            loading: () => const LoadingShimmer(height: 80),
            error: (_, __) => const Text('Verse not found'),
          ),

          const GoldDivider(),

          // Explain with AI
          if (_explanation == null)
            ElevatedButton.icon(
              onPressed: _loadingAi ? null : () => _explain(verseText),
              icon: _loadingAi
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(_loadingAi ? 'Explaining...' : 'Explain this verse with AI'),
            )
          else ...[
            Row(children: [
              const Icon(Icons.auto_awesome, color: AppTheme.gold, size: 16),
              const SizedBox(width: 8),
              Text('AI Explanation', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.gold)),
              const Spacer(),
              TextButton(onPressed: () => setState(() => _explanation = null), child: const Text('Clear')),
            ]),
            const SizedBox(height: 8),
            MarkdownBody(
              data: _explanation!,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),
          ],

          const GoldDivider(),

          // Cross references
          Text('Cross References', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          crossRefsAsync.when(
            loading: () => const LoadingShimmer(height: 60),
            error: (_, __) => const Text('Could not load cross references.'),
            data: (refs) => refs.isEmpty
                ? const Text('No cross references found.',
                    style: TextStyle(color: Colors.grey))
                : Column(
                    children: refs
                        .map((cr) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.navyVariant,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(cr.reference,
                                    style: const TextStyle(color: AppTheme.gold, fontSize: 12)),
                              ),
                              title: Text(cr.toBookName,
                                  style: Theme.of(context).textTheme.bodyMedium),
                              onTap: () => context.push(
                                  '/bible/verse?book=${Uri.encodeComponent(cr.toBookName)}&chapter=${cr.toChapter}&verse=${cr.toVerse}&translation=${widget.translation}'),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
