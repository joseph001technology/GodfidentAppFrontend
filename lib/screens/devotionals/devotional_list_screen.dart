import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/devotional.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/common/app_widgets.dart';

class DevotionalListScreen extends ConsumerWidget {
  const DevotionalListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devotionalsAsync = ref.watch(devotionalListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devotionals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outlined),
            onPressed: () => context.push('/more/devotionals/saved'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.gold,
        onRefresh: () async => ref.invalidate(devotionalListProvider),
        child: devotionalsAsync.when(
          loading: () => const ShimmerList(),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(devotionalListProvider),
          ),
          data: (devotionals) {
            if (devotionals.isEmpty) {
              return const EmptyView(
                icon: Icons.book_outlined,
                title: 'No devotionals yet',
                subtitle: 'Check back soon for daily content',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: devotionals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _DevotionalCard(devotional: devotionals[i]),
            );
          },
        ),
      ),
    );
  }
}

class _DevotionalCard extends StatelessWidget {
  final Devotional devotional;
  const _DevotionalCard({required this.devotional});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push('/more/devotionals/${devotional.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (devotional.isRead)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Read', style: TextStyle(color: Colors.green, fontSize: 10)),
                  ),
                Expanded(
                  child: Text(devotional.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                if (devotional.isSaved)
                  const Icon(Icons.bookmark, color: AppTheme.gold, size: 16),
              ]),
              const SizedBox(height: 6),
              Text(devotional.scriptureReference,
                  style: const TextStyle(color: AppTheme.gold, fontSize: 12)),
              const SizedBox(height: 8),
              Text(devotional.reflection,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
