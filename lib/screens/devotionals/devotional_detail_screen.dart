import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/remaining_providers.dart';
import '../../repositories/devotional_repository.dart';
import '../../widgets/common/app_widgets.dart';

class DevotionalDetailScreen extends ConsumerWidget {
  final int id;
  const DevotionalDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devotionalAsync = ref.watch(devotionalDetailProvider(id));

    return devotionalAsync.when(
      loading: () => Scaffold(appBar: AppBar(), body: const ShimmerList()),
      error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorView(message: e.toString())),
      data: (d) => Scaffold(
        appBar: AppBar(
          title: Text(d.title, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              icon: Icon(d.isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: d.isSaved ? AppTheme.gold : null),
              onPressed: () async {
                try {
                  if (d.isSaved) {
                    await DevotionalRepository().unsave(id);
                  } else {
                    await DevotionalRepository().save(id);
                  }
                  ref.invalidate(devotionalDetailProvider(id));
                  ref.invalidate(savedDevotionalsProvider);
                } catch (_) {}
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/ai/prayer-assistance'),
          icon: const Icon(Icons.volunteer_activism),
          label: const Text('Pray with AI'),
          backgroundColor: AppTheme.gold,
          foregroundColor: const Color(0xFF1A1A2E),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            // Scripture reference + text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.gold.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.scriptureReference,
                      style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(d.scriptureText,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic, height: 1.6)),
                ],
              ),
            ),
            const GoldDivider(),
            _Section(title: 'REFLECTION', content: d.reflection),
            const GoldDivider(),
            _Section(title: 'PRAYER', content: d.prayer, icon: Icons.volunteer_activism_outlined),
            if (d.application.isNotEmpty) ...[
              const GoldDivider(),
              _Section(title: 'APPLICATION', content: d.application),
            ],
            if (d.keyTakeaway.isNotEmpty) ...[
              const GoldDivider(),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.navyVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.navyOutline),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, color: AppTheme.gold, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('KEY TAKEAWAY',
                              style: TextStyle(color: AppTheme.gold, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          const SizedBox(height: 6),
                          Text(d.keyTakeaway, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String content;
  final IconData? icon;
  const _Section({required this.title, required this.content, this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          if (icon != null) ...[
            Icon(icon, color: AppTheme.gold, size: 14),
            const SizedBox(width: 6),
          ],
          Text(title,
              style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
        ]),
        const SizedBox(height: 10),
        Text(content, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7)),
      ],
    );
  }
}

// ── Saved Devotionals ─────────────────────────────────────────────────────────

class SavedDevotionalsScreen extends ConsumerWidget {
  const SavedDevotionalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedDevotionalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Devotionals')),
      body: savedAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (devotionals) {
          if (devotionals.isEmpty) {
            return const EmptyView(
              icon: Icons.bookmark_outline,
              title: 'No saved devotionals',
              subtitle: 'Tap the bookmark icon on any devotional to save it',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: devotionals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final d = devotionals[i];
              return Card(
                child: ListTile(
                  title: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(d.scriptureReference,
                      style: const TextStyle(color: AppTheme.gold, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/more/devotionals/${d.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
