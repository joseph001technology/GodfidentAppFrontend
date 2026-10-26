import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/remaining_providers.dart';
import '../../repositories/prayer_repository.dart';
import '../../services/prayer_notifications.dart';
import '../../widgets/common/app_widgets.dart';

class PrayerDetailScreen extends ConsumerWidget {
  final int id;
  const PrayerDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayersAsync = ref.watch(prayerListProvider);

    return prayersAsync.when(
      loading: () => Scaffold(appBar: AppBar(), body: const ShimmerList()),
      error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorView(message: friendlyError(e))),
      data: (prayers) {
        final matches = prayers.where((p) => p.id == id);
        if (matches.isEmpty) {
          return Scaffold(
            backgroundColor: AppTheme.navy,
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: const Center(child: Text('This prayer is no longer in your list.')),
          );
        }
        final prayer = matches.first;

        return Scaffold(
          backgroundColor: AppTheme.navy,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(prayer.title, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: AppTheme.gold),
                onPressed: () => context.push('/prayer/${prayer.id}/edit'),
                tooltip: 'Edit Prayer',
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') context.push('/prayer/${prayer.id}/edit');
                  if (v == 'delete') {
                    // Close the dialog with the DIALOG's own context. The screen's context
                    // belongs to another navigator (inside the bottom-bar shell), so popping
                    // with it closed the wrong thing and the buttons seemed dead.
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('Delete Prayer'),
                        content: const Text('Are you sure?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(prayerListProvider.notifier).delete(prayer.id);
                      await PrayerNotifications.clearPrayerReminder(prayer.id);
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
                  // An answered prayer is kept as a thanksgiving prayer.
                  label: Text(_cap(prayer.displayType)),
                  backgroundColor: AppTheme.navyVariant,
                  labelStyle: const TextStyle(color: AppTheme.gold, fontSize: 11),
                ),
                Chip(
                  label: Text(_cap(prayer.status)),
                  backgroundColor: prayer.isAnswered
                      ? Colors.green.withValues(alpha: 0.15)
                      : AppTheme.navyVariant,
                  labelStyle: TextStyle(
                    color: prayer.isAnswered ? Colors.green : AppTheme.textMuted,
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

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<void> _markAnswered(BuildContext context, WidgetRef ref, int id) async {
    // Grabbed before any await: the screen may rebuild while the list reloads.
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(prayerListProvider.notifier);
    final noteCtrl = TextEditingController();
    // Buttons close the dialog with the DIALOG's context (d). The screen's own
    // context sits in a different navigator (the bottom-bar shell), so using it
    // never closed the dialog: Cancel did nothing and the answer was never saved.
    final note = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppTheme.navySurface,
        title: const Text('Praise God! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How did God answer this prayer?'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Your testimony (optional)'),
            ),
            const SizedBox(height: 10),
            Text('It will be kept with your thanksgiving prayers.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(d, noteCtrl.text.trim()),
            child: const Text('Mark Answered'),
          ),
        ],
      ),
    );
    if (note == null) return; // Cancel, or tapped outside
    try {
      await notifier.markAnswered(id, note: note);
      await PrayerNotifications.clearPrayerReminder(id);
      messenger.showSnackBar(const SnackBar(content: Text('Praise God! Saved as answered, under Thanksgiving.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}
