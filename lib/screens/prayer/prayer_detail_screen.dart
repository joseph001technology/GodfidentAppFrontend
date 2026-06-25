import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/remaining_providers.dart';
import '../../repositories/prayer_repository.dart';
import '../../widgets/common/app_widgets.dart';

class PrayerDetailScreen extends ConsumerWidget {
  final int id;
  const PrayerDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayersAsync = ref.watch(prayerListProvider);

    return prayersAsync.when(
      loading: () => Scaffold(appBar: AppBar(), body: const ShimmerList()),
      error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorView(message: e.toString())),
      data: (prayers) {
        final prayer = prayers.firstWhere(
          (p) => p.id == id,
          orElse: () => prayers.first,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(prayer.title, overflow: TextOverflow.ellipsis),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') context.push('/prayer/${prayer.id}/edit');
                  if (v == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete Prayer'),
                        content: const Text('Are you sure?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(prayerListProvider.notifier).delete(prayer.id);
                      if (context.mounted) context.pop();
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Status + type badges
              Wrap(spacing: 8, children: [
                Chip(
                  label: Text(prayer.prayerType),
                  backgroundColor: AppTheme.navyVariant,
                  labelStyle: const TextStyle(color: AppTheme.gold, fontSize: 11),
                ),
                Chip(
                  label: Text(prayer.status),
                  backgroundColor: prayer.isAnswered
                      ? Colors.green.withOpacity(0.15)
                      : AppTheme.navyVariant,
                  labelStyle: TextStyle(
                    color: prayer.isAnswered ? Colors.green : Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ]),
              const GoldDivider(),
              Text(prayer.content,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7)),
              if (prayer.scripture.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(children: [
                  const Icon(Icons.menu_book_outlined, color: AppTheme.gold, size: 16),
                  const SizedBox(width: 8),
                  Text(prayer.scripture,
                      style: const TextStyle(color: AppTheme.gold, fontSize: 13)),
                ]),
              ],
              const GoldDivider(),

              // Actions
              if (!prayer.isAnswered)
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Mark Answered'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () => _markAnswered(context, ref, prayer.id),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.volunteer_activism, size: 16, color: AppTheme.gold),
                      label: const Text('Pray Again', style: TextStyle(color: AppTheme.gold)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.gold)),
                      onPressed: () async {
                        await PrayerRepository().logPrayer(prayer.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Amen! Prayer logged. 🙏')));
                          ref.read(prayerListProvider.notifier).load();
                        }
                      },
                    ),
                  ),
                ])
              else ...[
                const SectionHeader(title: 'TESTIMONY'),
                Text(
                  prayer.answeredNote.isNotEmpty
                      ? prayer.answeredNote
                      : 'God answered this prayer!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.green, fontStyle: FontStyle.italic),
                ),
              ],

              const SizedBox(height: 16),
              Text('Prayed ${prayer.timesPrayed} time(s)',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }

  Future<void> _markAnswered(BuildContext context, WidgetRef ref, int id) async {
    final noteCtrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.navySurface,
        title: const Text('Praise God! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How did God answer this prayer?'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Your testimony (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, noteCtrl.text), child: const Text('Mark Answered')),
        ],
      ),
    );
    if (note != null) {
      await ref.read(prayerListProvider.notifier).markAnswered(id, note: note);
    }
  }
}
