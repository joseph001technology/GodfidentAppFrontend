import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/rule.dart';
import '../../providers/rules_provider.dart';
import '../../widgets/common/app_widgets.dart';

class UniversalRulesScreen extends ConsumerStatefulWidget {
  const UniversalRulesScreen({super.key});

  @override
  ConsumerState<UniversalRulesScreen> createState() => _UniversalRulesScreenState();
}

class _UniversalRulesScreenState extends ConsumerState<UniversalRulesScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(rulesProvider);
    final categoriesAsync = ref.watch(ruleCategoriesProvider);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Text('📜 ', style: TextStyle(fontSize: 20)),
            Text(
              'Universal Rules',
              style: TextStyle(fontFamily: 'Lora', fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.gold),
            onPressed: () => context.push('/rules/new'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(rulesProvider);
          ref.invalidate(ruleCategoriesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Motivational Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2D1B69), Color(0xFF14142A)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PERMANENT DISCIPLINE',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.gold, letterSpacing: 1.2),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '"He who heeds instruction is on the path to life."',
                      style: TextStyle(fontFamily: 'Lora', fontSize: 15, fontStyle: FontStyle.italic, color: AppTheme.textPrimary),
                    ),
                    SizedBox(height: 4),
                    Text('— Proverbs 10:17', style: TextStyle(fontFamily: 'Lora', fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.gold)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Search Bar
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search rules...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                  fillColor: AppTheme.navySurface,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                ),
              ),

              const SizedBox(height: 16),

              // Category pills — pulled from GET /api/rules/categories/,
              // the categories you've actually created in-app.
              categoriesAsync.when(
                loading: () => const SizedBox(height: 38),
                error: (_, __) => const SizedBox.shrink(),
                data: (categories) => SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length + 1,
                    itemBuilder: (context, i) {
                      final label = i == 0 ? 'All' : categories[i - 1].name;
                      final isSelected = _selectedCategory == label;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = label),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.gold : AppTheme.navySurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? AppTheme.gold : Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppTheme.navy : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Rules List
              rulesAsync.when(
                loading: () => const LoadingShimmer(height: 200),
                error: (e, _) => ErrorView(message: e.toString()),
                data: (rules) {
                  final filtered = rules.where((r) {
                    final matchesCat = _selectedCategory == 'All' || (r.categoryName ?? '') == _selectedCategory;
                    final matchesQuery = _searchQuery.isEmpty ||
                        r.title.toLowerCase().contains(_searchQuery) ||
                        (r.description ?? '').toLowerCase().contains(_searchQuery);
                    return matchesCat && matchesQuery;
                  }).toList();

                  if (filtered.isEmpty) {
                    return EmptyView(
                      title: rules.isEmpty ? 'No rules yet' : 'No matching rules',
                      subtitle: rules.isEmpty ? 'Tap + to add your first rule' : 'Try a different search or category',
                      icon: Icons.rule,
                    );
                  }

                  return Column(children: filtered.map((r) => _buildRuleItem(context, ref, r)).toList());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleItem(BuildContext context, WidgetRef ref, Rule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: rule.isCompletedToday ? AppTheme.emerald.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              await ref.read(rulesProvider.notifier).toggleToday(rule.id);
              ref.invalidate(todayRulesProvider);
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: rule.isCompletedToday ? AppTheme.emerald : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check, size: 16, color: rule.isCompletedToday ? Colors.white : Colors.transparent),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.title,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: rule.isCompletedToday ? AppTheme.textMuted : AppTheme.textPrimary,
                    decoration: rule.isCompletedToday ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (rule.description != null && rule.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(rule.description!, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (rule.categoryName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text(rule.categoryName!, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.gold)),
                      ),
                    if (rule.currentStreak > 0) ...[
                      const SizedBox(width: 8),
                      Text('🔥 ${rule.currentStreak}d', style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.gold)),
                    ],
                    if (rule.isPinned) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.push_pin, color: AppTheme.gold, size: 12),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppTheme.textMuted, size: 18),
            onPressed: () => _showRuleActions(context, ref, rule),
          ),
        ],
      ),
    );
  }

  void _showRuleActions(BuildContext context, WidgetRef ref, Rule rule) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navySurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppTheme.gold),
              title: const Text('Edit Rule'),
              onTap: () {
                Navigator.pop(context);
                // Assumed route — confirm this matches your router.dart
                // (Notes uses the equivalent '/notes/{id}/edit' pattern).
                context.push('/rules/${rule.id}/edit');
              },
            ),
            ListTile(
              leading: Icon(rule.isFavorite ? Icons.favorite : Icons.favorite_border, color: AppTheme.accentPink),
              title: Text(rule.isFavorite ? 'Remove Favorite' : 'Mark Favorite'),
              onTap: () {
                ref.read(rulesProvider.notifier).toggleFavorite(rule.id);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Rule', style: TextStyle(color: Colors.red)),
              onTap: () {
                ref.read(rulesProvider.notifier).delete(rule.id);
                ref.invalidate(todayRulesProvider);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}