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
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Prayer Statistics',
          style: TextStyle(
            fontFamily: 'Lora',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: statsAsync.when(
        loading: () => const ShimmerList(count: 4),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(prayerStatsProvider),
        ),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Big numbers
            Row(children: [
              _BigStat(label: 'Total', value: '${stats.total}', color: AppTheme.gold),
              const SizedBox(width: 12),
              _BigStat(label: 'Answered', value: '${stats.answered}', color: AppTheme.emerald),
              const SizedBox(width: 12),
              _BigStat(label: 'Prayed', value: '${stats.timesPrayed}×', color: AppTheme.softBlue),
            ]),
            const SizedBox(height: 20),

            // Answer rate card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.navySurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Answer Rate',
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (stats.answerRate / 100).clamp(0.0, 1.0),
                      backgroundColor: AppTheme.navyVariant,
                      valueColor: const AlwaysStoppedAnimation(AppTheme.emerald),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${stats.answerRate.toStringAsFixed(1)}% of prayers answered 🎉',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.emerald,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // By type card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.navySurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Prayers by Type',
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (stats.byType.isEmpty)
                    const Text(
                      'No prayers recorded yet',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textMuted),
                    )
                  else
                    ...stats.byType.entries.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.key.isEmpty ? 'General' : e.key[0].toUpperCase() + e.key.substring(1),
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textPrimary),
                                ),
                              ),
                              Text(
                                '${e.value}',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.gold),
                              ),
                            ],
                          ),
                        )),
                ],
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
