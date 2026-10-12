import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/rule.dart';
import '../../providers/rules_provider.dart';
import '../../widgets/common/app_widgets.dart';
import '../../widgets/common/christian_art.dart';
import 'rule_widgets.dart';

/// Full view of one rule: title, the whole description, attached scriptures, edit / delete.
class RuleDetailScreen extends ConsumerWidget {
  final int ruleId;
  const RuleDetailScreen({super.key, required this.ruleId});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Rule rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppTheme.navySurface,
        title: const Text('Delete rule?'),
        content: Text('"${rule.title}" will be removed. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text('Delete', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(rulesProvider.notifier).delete(rule.id);
      ref.invalidate(todayRulesProvider);
      if (context.mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rule deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ruleDetailProvider(ruleId));
    return async.when(
      loading: () => Scaffold(
        backgroundColor: AppTheme.navy,
        appBar: AppBar(),
        body: const ShimmerList(),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppTheme.navy,
        appBar: AppBar(),
        body: ErrorView(message: friendlyError(e), onRetry: () => ref.invalidate(ruleDetailProvider(ruleId))),
      ),
      data: (rule) => _body(context, ref, rule),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, Rule rule) {
    final accent = ruleColorFromHex(rule.color);
    final desc = (rule.description ?? '').trim();

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: rule.isFavorite ? 'Remove favorite' : 'Mark favorite',
            icon: Icon(rule.isFavorite ? Icons.favorite : Icons.favorite_border, color: AppTheme.accentPink),
            onPressed: () async {
              await ref.read(rulesProvider.notifier).toggleFavorite(rule.id);
              ref.invalidate(ruleDetailProvider(ruleId));
            },
          ),
          IconButton(
            tooltip: 'Edit',
            icon: Icon(Icons.edit_outlined, color: AppTheme.goldAccent),
            onPressed: () async {
              await context.push('/rules/${rule.id}/edit');
              ref.invalidate(ruleDetailProvider(ruleId));
            },
          ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(Icons.delete_outline, color: AppTheme.danger),
            onPressed: () => _confirmDelete(context, ref, rule),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: KeyedArt(
                    artKey: 'rule_${rule.id}',
                    fallbackScene: sceneForId(rule.id),
                    height: 170,
                    width: double.infinity,
                    radius: 0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (rule.categoryName != null && rule.categoryName!.isNotEmpty)
                  _chip(rule.categoryName!, accent),
                if (rule.isPinned) _chip('Pinned', AppTheme.gold, icon: Icons.push_pin),
                if (rule.isDaily) _chip('Daily', AppTheme.emerald, icon: Icons.repeat_rounded),
                if (rule.currentStreak > 0)
                  _chip('${rule.currentStreak} day streak', AppTheme.accentPink, icon: Icons.local_fire_department_rounded),
              ]),
              const SizedBox(height: 14),
              Text(
                rule.title,
                style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 18),
              if (desc.isNotEmpty)
                SelectableText(
                  desc,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 16, height: 1.75, color: AppTheme.textPrimary),
                )
              else
                Text(
                  'No description yet. Tap the pencil to add one.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textMuted),
                ),
              if (rule.scriptures.isNotEmpty) ...[
                const SizedBox(height: 28),
                Row(children: [
                  Icon(Icons.menu_book_rounded, size: 18, color: AppTheme.goldAccent),
                  const SizedBox(width: 8),
                  Text(
                    rule.scriptures.length == 1 ? 'Scripture' : 'Scriptures',
                    style: TextStyle(
                        fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ]),
                const SizedBox(height: 12),
                for (final s in rule.scriptures)
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: ScriptureQuote(scripture: s)),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await ref.read(rulesProvider.notifier).toggleToday(rule.id);
                    ref.invalidate(todayRulesProvider);
                    ref.invalidate(ruleDetailProvider(ruleId));
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                    }
                  }
                },
                icon: Icon(rule.isCompletedToday ? Icons.check_circle : Icons.check_circle_outline),
                label: Text(rule.isCompletedToday ? 'Done today (tap to undo)' : 'Mark done today'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
        Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}
