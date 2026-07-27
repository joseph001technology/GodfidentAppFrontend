import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/progress_ring.dart' hide SectionHeader;
import '../../models/analytics.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/common/app_widgets.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _selectedTab = 0; // 0: Overview, 1: Calendar, 2: Badges

  @override
  Widget build(BuildContext context) {
    final dashAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🏆 ', style: TextStyle(fontSize: 22)),
                  Text(
                    'Spiritual Progress',
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Your journey with God, day by day',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),

              // Top Streaks Row
              _buildStreaksRow(dashAsync),

              const SizedBox(height: 20),

              // Overview / Calendar / Badges Pills
              _buildTabPills(),

              const SizedBox(height: 20),

              if (_selectedTab == 0) ...[
                // Monthly Consistency Card
                _buildMonthlyConsistencyCard(dashAsync),
                const SizedBox(height: 20),

                // Scripture Motivation Card
                _buildScriptureMotivationCard(),
                const SizedBox(height: 20),

                // 2x2 Stats Grid
                _buildStatsGrid(dashAsync),
              ] else if (_selectedTab == 1) ...[
                _buildCalendarTab(),
              ] else ...[
                _buildBadgesTab(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreaksRow(AsyncValue<Dashboard> dashAsync) {
    final prayerStreak = dashAsync.when(data: (d) => d.reading.currentStreak, loading: () => 7, error: (_, __) => 7);
    final bibleStreak = dashAsync.when(data: (d) => d.reading.currentStreak + 7, loading: () => 14, error: (_, __) => 14);

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4A2511), Color(0xFF2A1408)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  '$prayerStreak',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Text(
                  'Prayer Streak',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
                const Text(
                  'days in a row',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF14243A), Color(0xFF0D1624)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.softBlue.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Text('📖', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  '$bibleStreak',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Text(
                  'Bible Streak',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                ),
                const Text(
                  'days in a row',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabPills() {
    final tabs = ['Overview', 'Calendar', 'Badges'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final idx = e.key;
          final label = e.value;
          final isSelected = _selectedTab == idx;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppTheme.navy : AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthlyConsistencyCard(AsyncValue<Dashboard> dashAsync) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Consistency',
            style: TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 2),
          const Text(
            '19 of 26 days completed',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ProgressRing(
                progress: 0.73,
                size: 90,
                strokeWidth: 8,
                color: AppTheme.gold,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '73%',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'monthly',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildConsistencyBar('Prayer', 0.85, const Color(0xFFF59E0B)),
                    const SizedBox(height: 12),
                    _buildConsistencyBar('Bible', 0.78, AppTheme.emerald),
                    const SizedBox(height: 12),
                    _buildConsistencyBar('Focus', 0.92, AppTheme.accentPurple),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsistencyBar(String label, double pct, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary)),
            Text('${(pct * 100).toInt()}%', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildScriptureMotivationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1045), Color(0xFF0F0826)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentPurple.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text('🙌', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 12),
          const Text(
            '"Well done, good and faithful servant"',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Lora', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            '— Matthew 25:21',
            style: TextStyle(fontFamily: 'Lora', fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.gold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Keep pressing forward. You are becoming who God called you to be.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(AsyncValue<Dashboard> dashAsync) {
    final totalPrayers = dashAsync.when(data: (d) => d.prayer.totalPrayers, loading: () => 127, error: (_, __) => 127);
    final chaptersRead = dashAsync.when(data: (d) => d.reading.chaptersThisMonth, loading: () => 84, error: (_, __) => 84);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildBigStatCard('🙏', '$totalPrayers', 'Total Prayers', 'this year'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBigStatCard('📖', '$chaptersRead', 'Chapters Read', 'this month'),
            ),
          ],
        ),
        const SizedBox(width: 12, height: 12),
        Row(
          children: [
            Expanded(
              child: _buildBigStatCard('⏱️', '48h', 'Focus Hours', 'saved this week'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBigStatCard('🎯', '21', 'Best Streak', 'days (prayer)'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBigStatCard(String emoji, String val, String title, String sub) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 10),
          Text(val, style: const TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          Text(sub, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildCalendarTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Text('Activity Calendar', style: TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          SizedBox(height: 12),
          Text('Track your active devotion days over the current month.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted)),
          SizedBox(height: 20),
          Icon(Icons.calendar_month, size: 64, color: AppTheme.gold),
          SizedBox(height: 12),
          Text('19 active days in July 2026', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.emerald, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBadgesTab() {
    final badges = [
      {'title': '7-Day Prayer Streak', 'icon': '🔥', 'unlocked': true},
      {'title': '30-Day Prayer Streak', 'icon': '🏆', 'unlocked': false},
      {'title': '100 Prayers Logged', 'icon': '🙏', 'unlocked': true},
      {'title': 'Genesis Completed', 'icon': '📖', 'unlocked': true},
      {'title': '100 Notes Written', 'icon': '📝', 'unlocked': false},
      {'title': '1000 Verses Read', 'icon': '✨', 'unlocked': false},
    ];

    return Column(
      children: badges.map((b) {
        final isUnlocked = b['unlocked'] as bool;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.navySurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isUnlocked ? AppTheme.gold.withOpacity(0.3) : Colors.transparent),
          ),
          child: Row(
            children: [
              Text(b['icon'] as String, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  b['title'] as String,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked ? AppTheme.textPrimary : AppTheme.textMuted,
                  ),
                ),
              ),
              Icon(
                isUnlocked ? Icons.check_circle : Icons.lock_outline,
                color: isUnlocked ? AppTheme.gold : AppTheme.textMuted,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
