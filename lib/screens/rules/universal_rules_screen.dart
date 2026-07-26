import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/design_utils.dart';
import '../../models/universal_rule.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/premium_components.dart';

// ══════════════════════════════════════════════════════════════════════════
// UNIVERSAL RULES SCREEN
// ══════════════════════════════════════════════════════════════════════════

class UniversalRulesScreen extends ConsumerWidget {
  const UniversalRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(universalRulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spiritual Rules'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateRuleDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e'),
        ),
        data: (rules) => _buildRulesList(context, ref, rules),
      ),
    );
  }

  Widget _buildRulesList(BuildContext context, WidgetRef ref, List<UniversalRule> rules) {
    if (rules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '📌',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: DesignUtils.spacingLg),
            Text(
              'No rules yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: DesignUtils.spacingSm),
            Text(
              'Create personal spiritual rules to guide your journey',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignUtils.spacingLg),
            ElevatedButton(
              onPressed: () => _showCreateRuleDialog(context, ref),
              child: const Text('Create Your First Rule'),
            ),
          ],
        ),
      );
    }

    // Group rules by category
    final rulesByCategory = <RuleCategory, List<UniversalRule>>{};
    for (final rule in rules) {
      rulesByCategory.putIfAbsent(rule.category, () => []).add(rule);
    }

    // Pinned rules first
    final pinnedRules = rules.where((r) => r.isPinned).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(DesignUtils.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pinned Section
            if (pinnedRules.isNotEmpty) ...[
              Text(
                'Pinned Rules',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: DesignUtils.spacingMd),
              ...pinnedRules.map((rule) => _buildRuleCard(context, ref, rule)),
              const SizedBox(height: DesignUtils.spacingXl),
            ],

            // All Rules by Category
            Text(
              'All Rules',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: DesignUtils.spacingMd),
            ...rules.where((r) => !r.isPinned).map((rule) => _buildRuleCard(context, ref, rule)),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleCard(BuildContext context, WidgetRef ref, UniversalRule rule) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignUtils.spacingMd),
      child: GestureDetector(
        onTap: () => _showRuleActions(context, ref, rule),
        child: Container(
          padding: const EdgeInsets.all(DesignUtils.spacingMd),
          decoration: BoxDecoration(
            color: AppTheme.navyVariant,
            border: Border.all(
              color: rule.colorTag.startsWith('#')
                  ? _hexToColor(rule.colorTag)
                  : AppTheme.navyOutline,
              width: 1,
            ),
            borderRadius: DesignUtils.largeRadius,
            boxShadow: DesignUtils.subtleShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    rule.categoryEmoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: DesignUtils.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (rule.description.isNotEmpty) ...[
                          const SizedBox(height: DesignUtils.spacingXs),
                          Text(
                            rule.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (rule.isPinned)
                    const Icon(Icons.push_pin_rounded, color: AppTheme.gold),
                ],
              ),
              const SizedBox(height: DesignUtils.spacingMd),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignUtils.spacingMd,
                      vertical: DesignUtils.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.navySurface,
                      borderRadius: DesignUtils.smallRadius,
                    ),
                    child: Text(
                      rule.categoryLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.gold,
                          ),
                    ),
                  ),
                  if (rule.isCompletedToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignUtils.spacingMd,
                        vertical: DesignUtils.spacingSm,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withOpacity(0.2),
                        borderRadius: DesignUtils.smallRadius,
                        border: Border.all(
                          color: AppTheme.emerald,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        '✓ Completed',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.emerald,
                            ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRuleActions(BuildContext context, WidgetRef ref, UniversalRule rule) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(DesignUtils.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Mark as Completed'),
              onTap: () {
                ref.read(universalRulesProvider.notifier).markCompleted(rule.id);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: Text(rule.isPinned ? 'Unpin' : 'Pin'),
              onTap: () {
                ref.read(universalRulesProvider.notifier).togglePin(rule.id);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Open edit dialog
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                ref.read(universalRulesProvider.notifier).deleteRule(rule.id);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateRuleDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    var selectedCategory = RuleCategory.custom;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Rule'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  hintText: 'Rule title',
                  label: Text('Title'),
                ),
              ),
              const SizedBox(height: DesignUtils.spacingMd),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  hintText: 'Describe your rule',
                  label: Text('Description'),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: DesignUtils.spacingMd),
              DropdownButton<RuleCategory>(
                value: selectedCategory,
                isExpanded: true,
                items: RuleCategory.values
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat.toString().split('.').last),
                        ))
                    .toList(),
                onChanged: (cat) {
                  if (cat != null) selectedCategory = cat;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Create rule
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
