import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/progress_ring.dart' hide SectionHeader;
import '../../models/analytics.dart';
import '../../models/achievement.dart';
import '../../providers/achievements_provider.dart';
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
          ref.invalidate(monthlyReportProvider);
          ref.invalidate(heatmapProvider);
          ref.invalidate(prayerStreakProvider);
          ref.invalidate(focusAnalyticsProvider);
          ref.invalidate(prayerAnalyticsProvider);
          ref.invalidate(userAchievementsProvider);
          ref.invalidate(allAchievementsProvider);
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
                _buildMonthlyConsistencyCard(),
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

  /// Prayer streak comes from the dedicated PrayerStreak model/endpoint;
  /// Bible (reading) streak comes from the dashboard's reading stats.
  Widget _buildStreaksRow(AsyncValue<Dashboard> dashAsync) {
    final prayerStreakAsync = ref.watch(prayerStreakProvider);
    final prayerStreak = prayerStreakAsync.when(
      data: (s) => s.currentStreak,
      loading: () => 0,
      error: (_, __) => 0,
    );
    final bibleStreak = dashAsync.when(
      data: (d) => d.reading.currentStreak,
      loading: () => 0,
      error: (_, __) => 0,
    );

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

  Widget _buildMonthlyConsistencyCard() {
    final monthlyAsync = ref.watch(monthlyReportProvider);
    final prayerStreakAsync = ref.watch(prayerStreakProvider);
    final focusAsync = ref.watch(focusAnalyticsProvider);

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
          monthlyAsync.when(
            loading: () => const Text(
              'Loading this month…',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted),
            ),
            error: (_, __) => const Text(
              'Unable to load monthly stats',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted),
            ),
            data: (m) => Text(
              '${m.activeDays} of ${m.daysInMonth} active days',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              monthlyAsync.when(
                loading: () => ProgressRing(
                  progress: 0,
                  size: 90,
                  strokeWidth: 8,
                  color: AppTheme.gold,
                  child: const Text(
                    '…',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                error: (_, __) => ProgressRing(
                  progress: 0,
                  size: 90,
                  strokeWidth: 8,
                  color: AppTheme.gold,
                  child: const Text(
                    '—',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                data: (m) {
                  final pct = (m.consistencyScore / 100).clamp(0.0, 1.0);
                  return ProgressRing(
                    progress: pct,
                    size: 90,
                    strokeWidth: 8,
                    color: AppTheme.gold,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${m.consistencyScore.toStringAsFixed(0)}%',
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const Text(
                          'monthly',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildConsistencyBar(
                      'Prayer',
                      _prayerConsistency(prayerStreakAsync),
                      const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 12),
                    _buildConsistencyBar(
                      'Bible',
                      monthlyAsync.when(
                        data: (m) => m.daysInMonth > 0 ? (m.activeDays / m.daysInMonth).clamp(0.0, 1.0) : 0.0,
                        loading: () => 0.0,
                        error: (_, __) => 0.0,
                      ),
                      AppTheme.emerald,
                    ),
                    const SizedBox(height: 12),
                    _buildConsistencyBar(
                      'Focus',
                      _focusConsistency(focusAsync),
                      AppTheme.accentPurple,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Prayer consistency = days prayed this month / days elapsed in month.
  double _prayerConsistency(AsyncValue<PrayerStreak> async) {
    final now = DateTime.now();
    final daysElapsed = now.day; // 1..daysInMonth
    return async.when(
      data: (s) => daysElapsed > 0 ? (s.totalDaysPrayed / daysElapsed).clamp(0.0, 1.0) : 0.0,
      loading: () => 0.0,
      error: (_, __) => 0.0,
    );
  }

  /// Focus consistency = focus minutes this week / weekly target (210 min = 30 min/day).
  double _focusConsistency(AsyncValue<Map<String, dynamic>> async) {
    const weeklyTargetMinutes = 210.0;
    return async.when(
      data: (d) {
        final mins = (d['this_week_minutes'] ?? 0);
        final m = mins is int ? mins.toDouble() : (mins as num?)?.toDouble() ?? 0.0;
        return (m / weeklyTargetMinutes).clamp(0.0, 1.0);
      },
      loading: () => 0.0,
      error: (_, __) => 0.0,
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
    final totalPrayers = dashAsync.when(data: (d) => d.prayer.totalPrayers, loading: () => 0, error: (_, __) => 0);
    final chaptersRead = dashAsync.when(data: (d) => d.reading.chaptersThisMonth, loading: () => 0, error: (_, __) => 0);

    // Focus hours from the focus analytics endpoint.
    final focusAsync = ref.watch(focusAnalyticsProvider);
    final focusHours = focusAsync.when(
      data: (d) {
        final h = d['total_focus_hours'];
        return h is int ? h.toDouble() : (h as num?)?.toDouble() ?? 0.0;
      },
      loading: () => 0.0,
      error: (_, __) => 0.0,
    );

    // Best (longest) prayer streak from the PrayerStreak endpoint.
    final bestStreakAsync = ref.watch(prayerStreakProvider);
    final bestStreak = bestStreakAsync.when(
      data: (s) => s.longestStreak,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildBigStatCard('🙏', '$totalPrayers', 'Total Prayers', 'all time'),
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
              child: _buildBigStatCard('⏱️', '${focusHours.toStringAsFixed(1)}h', 'Focus Hours', 'total focused'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBigStatCard('🎯', '$bestStreak', 'Best Streak', 'days (prayer)'),
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

  /// Activity calendar driven by the analytics heatmap endpoint
  /// (Map<'YYYY-MM-DD', activityCount>). Renders the current month as a grid
  /// with gold intensity based on activity count.
  Widget _buildCalendarTab() {
    final heatmapAsync = ref.watch(heatmapProvider);
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final monthName = const ['January','February','March','April','May','June','July','August','September','October','November','December'][month - 1];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity Calendar',
            style: TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Daily reading activity — $monthName $year',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          heatmapAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: LoadingShimmer(height: 120))),
            error: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Unable to load activity data. Pull to refresh.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textMuted),
              ),
            ),
            data: (heatmap) {
              final activeDays = _countActiveDaysInMonth(heatmap, year, month);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: ['M','T','W','T','F','S','S'].map((d) => Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(d, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    )).toList(),
                  ),
                  _buildMonthGrid(heatmap, year, month),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Less', style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppTheme.textMuted)),
                      const SizedBox(width: 6),
                      ...List.generate(4, (i) => Container(
                        width: 12, height: 12, margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: _heatColor(i + 1, 4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )),
                      const SizedBox(width: 4),
                      const Text('More', style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppTheme.textMuted)),
                      const Spacer(),
                      Text(
                        '$activeDays active days in $monthName $year',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.emerald, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Badges driven by the Achievements endpoints: shows every achievement
  /// with its unlocked status from the user's achievement records.
  Widget _buildBadgesTab() {
    final allAsync = ref.watch(allAchievementsProvider);
    final userAsync = ref.watch(userAchievementsProvider);

    return allAsync.when(
      loading: () => const Column(children: [LoadingShimmer(height: 220)]),
      error: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Unable to load achievements. Pull to refresh.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textMuted),
        ),
      ),
      data: (achievements) {
        final unlocked = userAsync.when(
          data: (list) => list.where((u) => u.isUnlocked).map((u) => u.achievement.id).toSet(),
          loading: () => <int>{},
          error: (_, __) => <int>{},
        );
        if (achievements.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No achievements available yet.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textMuted),
            ),
          );
        }
        return Column(
          children: achievements.map((a) {
            final isUnlocked = unlocked.contains(a.id);
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
                  Text(a.icon.isNotEmpty ? a.icon : '🏆', style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isUnlocked ? AppTheme.textPrimary : AppTheme.textMuted,
                          ),
                        ),
                        if (a.description.isNotEmpty)
                          Text(
                            a.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted),
                          ),
                      ],
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
      },
    );
  }

  Widget _buildMonthGrid(Map<String, int> heatmap, int year, int month) {
    final firstOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday - 1; // Mon=1 .. Sun=7
    final cells = <Widget?>[];
    for (int i = 0; i < leadingBlanks; i++) {
      cells.add(null);
    }
    int maxCount = 1;
    for (int day = 1; day <= daysInMonth; day++) {
      final c = heatmap[_dateKey(year, month, day)] ?? 0;
      if (c > maxCount) maxCount = c;
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final count = heatmap[_dateKey(year, month, day)] ?? 0;
      cells.add(Container(
        height: 30,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: count > 0 ? _heatColor(count, maxCount) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(6),
          border: count > 0 ? null : Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            color: count > 0 ? AppTheme.navy : AppTheme.textMuted,
            fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return Column(
      children: List.generate(cells.length ~/ 7, (row) {
        return Row(
          children: List.generate(7, (col) {
            final cell = cells[row * 7 + col];
            return Expanded(child: cell ?? Container(height: 30, margin: const EdgeInsets.all(2)));
          }),
        );
      }),
    );
  }

  String _dateKey(int y, int m, int d) =>
      '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

  int _countActiveDaysInMonth(Map<String, int> heatmap, int year, int month) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    int count = 0;
    for (int day = 1; day <= daysInMonth; day++) {
      if ((heatmap[_dateKey(year, month, day)] ?? 0) > 0) count++;
    }
    return count;
  }

  Color _heatColor(int count, int maxCount) {
    if (count <= 0) return Colors.white.withOpacity(0.04);
    final ratio = (count / maxCount).clamp(0.0, 1.0);
    if (ratio > 0.75) return const Color(0xFFF59E0B);
    if (ratio > 0.5) return const Color(0xFFFBBF24);
    if (ratio > 0.25) return const Color(0xFFFCD34D);
    return const Color(0xFFFDE68A);
  }
}
