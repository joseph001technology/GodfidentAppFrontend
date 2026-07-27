import 'package:flutter/material.dart';
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
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 52, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('\u{1F3C6} Spiritual Progress',
                    style: TextStyle(fontFamily: 'Lora', fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 16),
                prayerStreakAsync.when(
                  loading: () => const _StreakShimmer(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (streak) => _StreakCards(streak: streak),
                ),
                const SizedBox(height: 20),
                _buildSegmentedControl(),
              ]),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [_buildOverview(), _buildCalendar(), _buildBadges()],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      decoration: BoxDecoration(color: AppTheme.navyVariant, borderRadius: BorderRadius.circular(14)),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
        ),
        labelColor: AppTheme.gold,
        unselectedLabelColor: AppTheme.textMuted,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [Tab(text: 'Overview'), Tab(text: 'Calendar'), Tab(text: 'Badges')],
      ),
    );
  }

  Widget _buildOverview() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(children: [
        _ConsistencyCard(),
        SizedBox(height: 16),
        _StatsGrid(),
        SizedBox(height: 16),
        _MotivationalCard(),
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
                decoration: BoxDecoration(
                  color: (i % 5) > 2 ? AppTheme.emerald.withValues(alpha: 0.6) : AppTheme.navyOutline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildBadges() {
    final userAchievementsAsync = ref.watch(userAchievementsProvider);
    final allAchievementsAsync = ref.watch(allAchievementsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Your Achievements', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        userAchievementsAsync.when(
          loading: () => const _BadgesLoading(),
          error: (_, __) => const SizedBox.shrink(),
          data: (badges) => badges.isEmpty
            ? const Padding(padding: EdgeInsets.all(32), child: Text('Complete activities to earn achievements!', style: TextStyle(color: AppTheme.textMuted)))
            : _BadgesGrid(badges: badges),
        ),
        const SizedBox(height: 20),
        const Text('All Achievements', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        allAchievementsAsync.when(
          loading: () => const _BadgesLoading(),
          error: (_, __) => const SizedBox.shrink(),
          data: (all) => _AllBadgesGrid(achievements: all),
        ),
      ]),
    );
  }
}

// ── Shared Widgets ──────────────────────────────────────────────────────────

class _StreakShimmer extends StatelessWidget {
  const _StreakShimmer();
  @override
  Widget build(BuildContext context) {
    return const Row(children: [
      Expanded(child: LoadingShimmer(height: 72, borderRadius: 18)),
      SizedBox(width: 10),
      Expanded(child: LoadingShimmer(height: 72, borderRadius: 18)),
    ]);
  }
}

class _StreakCards extends StatelessWidget {
  final PrayerStreak streak;
  const _StreakCards({required this.streak});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _StreakCard(emoji: '\u{1F64F}', value: '${streak.currentStreak}', label: 'Prayer Streak', gradient: Gradients.streak),
      const SizedBox(width: 10),
      _StreakCard(emoji: '\u{1F4D6}', value: '${streak.longestStreak}', label: 'Bible Streak', gradient: Gradients.bibleReading),
    ]);
  }
}

class _StreakCard extends StatelessWidget {
  final String emoji, value, label;
  final LinearGradient gradient;
  const _StreakCard({required this.emoji, required this.value, required this.label, required this.gradient});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textSecondary)),
          ]),
        ]),
      ),
    );
  }
}

class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(20)),
      child: const Row(children: [
        ProgressRing(progress: 0.72, size: 80, strokeWidth: 8,
          child: Text('72%', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.gold)),
        ),
        SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Monthly Consistency', style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          SizedBox(height: 8),
          _CategoryBar(label: 'Prayer', value: 0.8, color: AppTheme.gold),
          _CategoryBar(label: 'Bible', value: 0.65, color: AppTheme.accentPurple),
          _CategoryBar(label: 'Focus', value: 0.45, color: AppTheme.emerald),
        ])),
      ]),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String label; final double value; final Color color;
  const _CategoryBar({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
      SizedBox(width: 50, child: Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textSecondary))),
      const SizedBox(width: 8),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(value: value.clamp(0.0, 1.0), minHeight: 6,
            backgroundColor: AppTheme.navyOutline, valueColor: AlwaysStoppedAnimation<Color>(color)))),
      const SizedBox(width: 8),
      Text('${(value * 100).toInt()}%', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    ]));
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(20)),
      child: const Column(children: [
        Row(children: [_StatItem(emoji: '\u{1F64F}', value: '24', label: 'Total Prayers'), SizedBox(width: 12), _StatItem(emoji: '\u{1F4D6}', value: '12', label: 'Chapters')]),
        SizedBox(height: 12),
        Row(children: [_StatItem(emoji: '\u{23F1}\u{FE0F}', value: '8h', label: 'Focus Hrs'), SizedBox(width: 12), _StatItem(emoji: '\u{1F525}', value: '7d', label: 'Best Streak')]),
      ]),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String emoji, value, label;
  const _StatItem({required this.emoji, required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.navyVariant, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppTheme.textMuted)),
        ]),
      ]),
    ));
  }
}

class _MotivationalCard extends StatelessWidget {
  const _MotivationalCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: Gradients.verseOfDay, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('"I can do all things through Christ who strengthens me."',
            style: TextStyle(fontFamily: 'Lora', fontSize: 15, fontStyle: FontStyle.italic, color: Colors.white, height: 1.5)),
        const SizedBox(height: 8),
        Text('Philippians 4:13',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.gold.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _BadgesLoading extends StatelessWidget {
  const _BadgesLoading();
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.9, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: 6, itemBuilder: (_, i) => const LoadingShimmer(height: 100),
    );
  }
}

class _BadgesGrid extends StatelessWidget {
  final List<UserAchievement> badges;
  const _BadgesGrid({required this.badges});
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.9, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: badges.length,
      itemBuilder: (_, i) => _BadgeCard(ua: badges[i]),
    );
  }
}

class _AllBadgesGrid extends StatelessWidget {
  final List<Achievement> achievements;
  const _AllBadgesGrid({required this.achievements});
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.9, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: achievements.length,
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.navyVariant, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.navyOutline)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(achievements[i].icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(achievements[i].name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
        ]),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final UserAchievement ua;
  const _BadgeCard({required this.ua});
  @override
  Widget build(BuildContext context) {
    final locked = !ua.isUnlocked;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: locked ? AppTheme.navyVariant : AppTheme.navySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: locked ? AppTheme.navyOutline : ua.isRecent ? AppTheme.gold.withValues(alpha: 0.4) : Colors.transparent),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(ua.achievement.icon, style: TextStyle(fontSize: 28, color: locked ? AppTheme.textMuted : null)),
        const SizedBox(height: 6),
        Text(ua.achievement.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w600, color: locked ? AppTheme.textMuted : AppTheme.textPrimary)),
      ]),
    );
  }
}