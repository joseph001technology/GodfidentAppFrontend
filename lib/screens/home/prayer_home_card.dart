import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/prayer.dart';
import '../../providers/achievements_provider.dart';
import '../../providers/remaining_providers.dart';
import '../../services/daily_activity.dart';
import '../../services/prayer_notifications.dart';
import '../prayer/prayer_launch.dart';

/// The Prayer section of Home: a "Pray now" hero that starts Prayer Focus,
/// today's prayed status, streak, active / answered counts and quick actions.
class PrayerHomeCard extends ConsumerStatefulWidget {
  const PrayerHomeCard({super.key});

  @override
  ConsumerState<PrayerHomeCard> createState() => _PrayerHomeCardState();
}

class _PrayerHomeCardState extends ConsumerState<PrayerHomeCard> {
  bool _prayedLocal = false;

  @override
  void initState() {
    super.initState();
    // Re-arm the daily prayer times and per-request reminders whenever Home loads.
    PrayerNotifications.ensureScheduled();
    _refreshPrayed();
  }

  Future<void> _refreshPrayed() async {
    final v = await prayedToday();
    if (mounted) setState(() => _prayedLocal = v);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Prayer>>>(prayerListProvider, (prev, next) {
      final list = next.valueOrNull;
      if (list != null) PrayerNotifications.syncWithPrayers(list);
    });
    final prayers = ref.watch(prayerListProvider).valueOrNull;
    final streak = ref.watch(prayerStreakProvider).valueOrNull;

    final prayedToday = _prayedLocal ||
        ((streak?.lastPrayerDate ?? '').startsWith(DailyActivity.today()));
    final active = prayers == null ? null : prayers.where((p) => !p.isAnswered).length;
    final answered = prayers == null ? null : prayers.where((p) => p.isAnswered).length;
    final days = streak?.currentStreak ?? 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/prayer'),
        child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.heroSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.heroBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.gold.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: Icon(
                prayedToday ? Icons.check : Icons.volunteer_activism,
                color: AppTheme.heroAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(prayedToday ? 'You prayed today' : 'Pray now',
                    style: TextStyle(
                        fontFamily: 'Lora', fontSize: 21, fontWeight: FontWeight.bold, color: AppTheme.onHero)),
                const SizedBox(height: 2),
                Text(
                  prayedToday
                      ? 'Thank you, Lord. Keep the conversation going.'
                      : 'Pray without ceasing. — 1 Thessalonians 5:17',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.onHeroMuted),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _inkStat(Icons.local_fire_department_outlined, '$days', days == 1 ? 'day streak' : 'day streak'),
            _inkStat(Icons.volunteer_activism_outlined, active == null ? '–' : '$active', 'active requests'),
            _inkStat(Icons.check_circle_outline, answered == null ? '–' : '$answered', 'answered'),
          ]),
        ]),
      ),
      ),
    ]);
  }

  Widget _inkStat(IconData icon, String value, String label) => Expanded(
        child: Column(children: [
          Icon(icon, color: AppTheme.heroAccent, size: 18),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.onHero)),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: AppTheme.onHeroMuted)),
        ]),
      );

  Widget _action(IconData icon, String label, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.navySurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.navyOutline),
          ),
          child: Column(children: [
            Icon(icon, color: AppTheme.goldDark, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ]),
        ),
      );
}
