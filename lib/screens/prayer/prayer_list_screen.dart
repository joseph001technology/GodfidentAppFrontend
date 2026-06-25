import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/prayer.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/common/app_widgets.dart';

class PrayerListScreen extends ConsumerWidget {
  const PrayerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayersAsync = ref.watch(prayerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Journal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () => context.push('/prayer/stats'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/prayer/new');
          ref.read(prayerListProvider.notifier).load();
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        color: AppTheme.gold,
        onRefresh: () => ref.read(prayerListProvider.notifier).load(),
        child: prayersAsync.when(
          loading: () => const ShimmerList(),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.read(prayerListProvider.notifier).load(),
          ),
          data: (prayers) {
            if (prayers.isEmpty) {
              return const EmptyView(
                icon: Icons.volunteer_activism_outlined,
                title: 'No prayers yet',
                subtitle: 'Tap + to add your first prayer',
              );
            }
            final active = prayers.where((p) => p.isActive).toList();
            final answered = prayers.where((p) => p.isAnswered).toList();

            return ListView(
              children: [
                if (active.isNotEmpty) ...[
                  const SectionHeader(title: 'ACTIVE'),
                  ...active.map((p) => _PrayerTile(prayer: p)),
                ],
                if (answered.isNotEmpty) ...[
                  const SectionHeader(title: 'ANSWERED'),
                  ...answered.map((p) => _PrayerTile(prayer: p)),
                ],
                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PrayerTile extends ConsumerWidget {
  final Prayer prayer;
  const _PrayerTile({required this.prayer});

  Color get _typeColor {
    switch (prayer.prayerType) {
      case 'praise': return Colors.amber;
      case 'intercession': return Colors.blue;
      case 'thanksgiving': return Colors.green;
      default: return AppTheme.gold;
    }
  }

  IconData get _typeIcon {
    switch (prayer.prayerType) {
      case 'praise': return Icons.celebration_outlined;
      case 'intercession': return Icons.people_outline;
      case 'thanksgiving': return Icons.favorite_outline;
      default: return Icons.volunteer_activism_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _typeColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(_typeIcon, color: _typeColor, size: 20),
        ),
        title: Text(prayer.title,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prayer.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
            if (prayer.timesPrayed > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Prayed ${prayer.timesPrayed}×',
                    style: TextStyle(color: _typeColor, fontSize: 11)),
              ),
          ],
        ),
        trailing: prayer.isAnswered
            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
            : null,
        onTap: () async {
          await context.push('/prayer/${prayer.id}');
          ref.read(prayerListProvider.notifier).load();
        },
      ),
    );
  }
}
