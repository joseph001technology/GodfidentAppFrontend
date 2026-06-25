import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/reading_plan.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/common/app_widgets.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(readingPlansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Plans'),
        actions: [
          TextButton(
            onPressed: () => context.push('/more/my-plans'),
            child: const Text('My Plans', style: TextStyle(color: AppTheme.gold)),
          ),
        ],
      ),
      body: plansAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(readingPlansProvider),
        ),
        data: (plans) {
          if (plans.isEmpty) {
            return const EmptyView(
              icon: Icons.list_alt_outlined,
              title: 'No plans available',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _PlanCard(plan: plans[i]),
          );
        },
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  final ReadingPlan plan;
  const _PlanCard({required this.plan});

  Color get _typeColor {
    switch (plan.planType) {
      case 'gospel': return Colors.blue;
      case 'nt': return Colors.purple;
      case 'proverbs': return Colors.amber;
      default: return AppTheme.gold;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _typeColor.withOpacity(0.4)),
                ),
                child: Text(plan.planType,
                    style: TextStyle(color: _typeColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text('${plan.durationDays} days',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.gold)),
            ]),
            const SizedBox(height: 10),
            Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(plan.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.gold,
                    side: const BorderSide(color: AppTheme.navyOutline),
                  ),
                  onPressed: () => _showDetails(context, ref, plan),
                  child: const Text('View Plan'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _enroll(context, ref, plan),
                  child: const Text('Enroll'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _enroll(BuildContext context, WidgetRef ref, ReadingPlan plan) async {
    try {
      await ref.read(myPlansProvider.notifier).enroll(plan.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enrolled in "${plan.name}"!')));
        context.push('/more/my-plans');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already enrolled or error occurred.')));
      }
    }
  }

  void _showDetails(BuildContext context, WidgetRef ref, ReadingPlan plan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navySurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(plan.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('${plan.durationDays} days', style: const TextStyle(color: AppTheme.gold)),
              const SizedBox(height: 12),
              Text(plan.description, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
