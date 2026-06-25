import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/common/app_widgets.dart';

class PrayerStatsScreen extends ConsumerWidget {
  const PrayerStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(prayerStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Statistics')),
      body: statsAsync.when(
        loading: () => const ShimmerList(count: 4),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Big numbers
            Row(children: [
              _BigStat(label: 'Total', value: '${stats.total}', color: AppTheme.gold),
              const SizedBox(width: 12),
              _BigStat(label: 'Answered', value: '${stats.answered}', color: Colors.green),
              const SizedBox(width: 12),
              _BigStat(label: 'Times Prayed', value: '${stats.timesPrayed}', color: Colors.blue),
            ]),
            const SizedBox(height: 20),

            // Answer rate
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Answer Rate', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: stats.answerRate / 100,
                      backgroundColor: AppTheme.navyVariant,
                      valueColor: const AlwaysStoppedAnimation(Colors.green),
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    const SizedBox(height: 8),
                    Text('${stats.answerRate.toStringAsFixed(1)}% of prayers answered',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // By type
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('By Type', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ...stats.byType.entries.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            Expanded(child: Text(e.key[0].toUpperCase() + e.key.substring(1))),
                            Text('${e.value}', style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700)),
                          ]),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BigStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color)),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
