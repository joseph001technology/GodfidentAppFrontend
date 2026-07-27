import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/rules_provider.dart';
import '../../widgets/common/app_widgets.dart';

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(todayRulesProvider);
    return Scaffold(
      body: RefreshIndicator(onRefresh: () async => ref.invalidate(todayRulesProvider),
        child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Today's Rules", style: TextStyle(fontFamily: 'Lora', fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            rulesAsync.when(loading: () => const ShimmerList(count: 4),
              error: (_, __) => const ErrorView(message: 'Could not load rules'),
              data: (rules) => rules.isEmpty ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No rules yet', style: TextStyle(color: AppTheme.textMuted))))
                : ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    itemCount: rules.length,
                    itemBuilder: (_, i) =>Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Checkbox(value: rules[i].isCompleted, onChanged: null, activeColor: AppTheme.gold),
                        Expanded(child: Text(rules[i].title, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textPrimary))),
                      ]),
                    ),
                  ),
            ),
          ]),
        ),
      ),
    );
  }
}
