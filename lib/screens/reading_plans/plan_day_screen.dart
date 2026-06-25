import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/common/app_widgets.dart';

class PlanDayScreen extends ConsumerWidget {
  final int planId;
  const PlanDayScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(myPlansProvider);

    return plansAsync.when(
      loading: () => Scaffold(appBar: AppBar(), body: const ShimmerList()),
      error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorView(message: e.toString())),
      data: (plans) {
        final userPlan = plans.firstWhere(
          (p) => p.id == planId,
          orElse: () => plans.first,
        );
        final day = userPlan.currentDayDetail;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Day ${userPlan.currentDay}'),
                Text(
                  userPlan.plan.name,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Progress
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: userPlan.progressPercent / 100,
                  backgroundColor: AppTheme.navyVariant,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.gold),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Day ${userPlan.currentDay} of ${userPlan.plan.durationDays}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const GoldDivider(),

              if (day == null)
                const EmptyView(icon: Icons.check_circle, title: 'All days complete!')
              else ...[
                Text(day.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                Text('Today\'s readings:', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.gold)),
                const SizedBox(height: 12),
                ...day.readings.map((r) {
                  final book = r['book'] ?? '';
                  final start = r['chapter_start'] ?? 1;
                  final end = r['chapter_end'] ?? start;
                  final label = start == end ? '$book $start' : '$book $start–$end';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.menu_book_outlined, color: AppTheme.gold),
                      title: Text(label, style: Theme.of(context).textTheme.titleMedium),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      onTap: () => context.push(
                          '/bible/chapter?book=${Uri.encodeComponent(book)}&chapter=$start&translation=KJV'),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Mark Day Complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  onPressed: () => _markComplete(context, ref, userPlan.id, userPlan.currentDay),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _markComplete(BuildContext context, WidgetRef ref, int userPlanId, int dayNumber) async {
    try {
      await ref.read(myPlansProvider.notifier).completeDay(userPlanId, dayNumber: dayNumber);
      ref.invalidate(readingStreakProvider);
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppTheme.navySurface,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 56),
                const SizedBox(height: 12),
                Text('Day $dayNumber Complete!',
                    style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('Well done! Keep going 🔥', textAlign: TextAlign.center),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () { Navigator.pop(context); context.pop(); },
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())));
      }
    }
  }
}
