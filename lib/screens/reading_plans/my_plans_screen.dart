import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/reading_plan.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/common/app_widgets.dart';

class MyPlansScreen extends ConsumerWidget {
  const MyPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(myPlansProvider);
    final streakAsync = ref.watch(readingStreakProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Reading Plans')),
      body: RefreshIndicator(
        color: AppTheme.gold,
        onRefresh: () => ref.read(myPlansProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Streak card
            streakAsync.when(
              data: (streak) => _StreakCard(streak: streak),
              loading: () => const LoadingShimmer(height: 80),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'ACTIVE PLANS'),
            plansAsync.when(
              loading: () => const ShimmerList(count: 3),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.read(myPlansProvider.notifier).load(),
              ),
              data: (plans) {
                if (plans.isEmpty) {
                  return EmptyView(
                    icon: Icons.list_alt_outlined,
                    title: 'No plans yet',
                    subtitle: 'Browse reading plans to get started',
                    action: ElevatedButton(
                      onPressed: () => context.push('/more/plans'),
                      child: const Text('Browse Plans'),
                    ),
                  );
                }
                return Column(
                  children: plans
                      .map((p) => _UserPlanCard(userPlan: p))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final dynamic streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.gold.withOpacity(0.25), AppTheme.navyVariant],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department, color: Colors.orange, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${streak.currentStreak}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppTheme.gold),
                      ),
                      TextSpan(
                        text: ' day streak',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Text('Longest: ${streak.longestStreak} days  ·  Total: ${streak.totalDaysRead} days',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserPlanCard extends ConsumerWidget {
  final UserReadingPlan userPlan;
  const _UserPlanCard({required this.userPlan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(userPlan.plan.name,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              _StatusChip(status: userPlan.status),
            ]),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: userPlan.progressPercent / 100,
                backgroundColor: AppTheme.navyVariant,
                valueColor: const AlwaysStoppedAnimation(AppTheme.gold),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Day ${userPlan.currentDay} of ${userPlan.plan.durationDays}  ·  ${userPlan.progressPercent.toStringAsFixed(0)}% complete',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (userPlan.currentDayDetail != null) ...[
              const SizedBox(height: 8),
              Text('Today: ${userPlan.currentDayDetail!.readingsSummary}',
                  style: const TextStyle(color: AppTheme.gold, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            Row(children: [
              if (userPlan.isActive) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.push('/more/plans/${userPlan.id}/day'),
                    child: const Text('Continue Reading'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.pause_outlined, color: Colors.grey),
                  onPressed: () => ref.read(myPlansProvider.notifier).pause(userPlan.id),
                  tooltip: 'Pause',
                ),
              ] else if (userPlan.isPaused) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 16, color: AppTheme.gold),
                    label: const Text('Resume', style: TextStyle(color: AppTheme.gold)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.gold)),
                    onPressed: () => ref.read(myPlansProvider.notifier).resume(userPlan.id),
                  ),
                ),
              ] else if (userPlan.isCompleted) ...[
                const Row(children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  SizedBox(width: 6),
                  Text('Completed!', style: TextStyle(color: Colors.green)),
                ]),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color get color {
    switch (status) {
      case 'active': return Colors.green;
      case 'paused': return Colors.orange;
      case 'completed': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
