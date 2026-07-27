import os

BASE = r'C:\PROJECTS\REALPROJECTS\REAL\Godfident-django\godfident_flutter-v2'

# Progress screen
progress_content = '''import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/progress_ring.dart';
import '../../providers/achievements_provider.dart';
import '../../widgets/common/app_widgets.dart';
import '../../models/achievement.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});
  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() { super.initState(); _tabController = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final prayerStreakAsync = ref.watch(prayerStreakProvider);
    final userAchievementsAsync = ref.watch(userAchievementsProvider);
    final allAchievementsAsync = ref.watch(allAchievementsProvider);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 52, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('\u{1F3C6} Spiritual Progress',
                    style: const TextStyle(fontFamily: 'Lora', fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 16),
                prayerStreakAsync.when(
                  loading: () => Row(children: const [Expanded(child: LoadingShimmer(height: 72)), SizedBox(width: 10), Expanded(child: LoadingShimmer(height: 72))]),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (streak) => Row(children: [
                    Expanded(child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(gradient: Gradients.streak, borderRadius: BorderRadius.circular(18)),
                      child: Row(children: [
                        const Text('\u{1F64F}', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${streak.currentStreak}', style: const TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          const Text('Prayer Streak', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textSecondary)),
                        ]),
                      ]),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(gradient: Gradients.bibleReading, borderRadius: BorderRadius.circular(18)),
                      child: Row(children: [
                        const Text('\u{1F4D6}', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${streak.longestStreak}', style: const TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          const Text('Bible Streak', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textSecondary)),
                        ]),
                      ]),
                    )),
                  ]),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(color: AppTheme.navyVariant, borderRadius: BorderRadius.circular(14)),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(color: AppTheme.gold.withOpacity(0.2), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.gold.withOpacity(0.3))),
                    labelColor: AppTheme.gold,
                    unselectedLabelColor: AppTheme.textMuted,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [Tab(text: 'Overview'), Tab(text: 'Calendar'), Tab(text: 'Badges')],
                  ),
                ),
              ]),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverview(),
            _buildCalendar(),
            _buildBadges(userAchievementsAsync, allAchievementsAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            ProgressRing(progress: 0.72, size: 80, strokeWidth: 8,
              child: Text('72%', style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.gold))),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Monthly Consistency', style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              _buildBar('Prayer', 0.8, AppTheme.gold),
              _buildBar('Bible', 0.65, AppTheme.accentPurple),
              _buildBar('Focus', 0.45, AppTheme.emerald),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Row(children: [ _statItem('\u{1F64F}', '24', 'Total Prayers'), const SizedBox(width: 12), _statItem('\u{1F4D6}', '12', 'Chapters') ]),
            const SizedBox(height: 12),
            Row(children: [ _statItem('\u{23F1}\u{FE0F}', '8h', 'Focus Hrs'), const SizedBox(width: 12), _statItem('\u{1F525}', '7d', 'Best Streak') ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCalendar() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          const Text('Activity Heatmap', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 20, childAspectRatio: 1, crossAxisSpacing: 3, mainAxisSpacing: 3),
              itemCount: 140,
              itemBuilder: (_, i) => Container(
                decoration: BoxDecoration(color: (i % 5) > 2 ? AppTheme.emerald.withOpacity(0.6) : AppTheme.navyOutline.withOpacity(0.3), borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildBadges(AsyncValue<List<UserAchievement>> userAchievements, AsyncV
