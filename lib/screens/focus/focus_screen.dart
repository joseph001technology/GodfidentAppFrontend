import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../providers/focus_provider.dart';
import '../../widgets/common/app_widgets.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(focusStatsProvider);
    final blockedAppsAsync = ref.watch(blockedAppsProvider);
    final sessionAsync = ref.watch(activeSessionProvider);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(focusStatsProvider);
          ref.invalidate(blockedAppsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(sessionAsync),
              const SizedBox(height: 6),
              const Text(
                'Protect your attention. Honor God with your time.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              _buildStatsRow(statsAsync),
              const SizedBox(height: 24),
              _buildWeeklyChartSection(),
              const SizedBox(height: 24),
              _buildMostUsedAppsSection(),
              const SizedBox(height: 24),
              _buildBlockedAppsSection(blockedAppsAsync),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AsyncValue<dynamic> sessionAsync) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            Text('🎯 ', style: TextStyle(fontSize: 22)),
            Text(
              'Digital Focus',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        sessionAsync.when(
          data: (session) {
            final isActive = session != null && session.isActive;
            return OutlinedButton.icon(
              onPressed: () => isActive
                  ? ref.read(activeSessionProvider.notifier).end()
                  : ref.read(activeSessionProvider.notifier).start(),
              style: OutlinedButton.styleFrom(
                foregroundColor: isActive ? const Color(0xFFEF4444) : AppTheme.gold,
                side: BorderSide(color: isActive ? const Color(0xFFEF4444) : AppTheme.gold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: Icon(isActive ? Icons.stop : Icons.play_arrow, size: 16),
              label: Text(
                isActive ? 'End Focus' : 'Start Focus',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildStatsRow(AsyncValue<dynamic> statsAsync) {
    return statsAsync.when(
      loading: () => const LoadingShimmer(height: 90),
      error: (_, __) => _buildStatsContainer('82%', '3.3h', '2h 14m'),
      data: (stats) {
        final score = '${stats.averageFocusScore.toInt()}%';
        final screen = '${stats.totalFocusMinutes ~/ 60}.${(stats.totalFocusMinutes % 60) ~/ 6}h';
        final saved = '${stats.timeSavedMinutes ~/ 60}h ${stats.timeSavedMinutes % 60}m';
        return _buildStatsContainer(score, screen, saved);
      },
    );
  }

  Widget _buildStatsContainer(String score, String screenTime, String timeSaved) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: '🎯',
            label: 'Focus Score',
            value: score.isNotEmpty ? score : '82%',
            color: AppTheme.gold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: '📱',
            label: 'Avg Screen',
            value: screenTime.isNotEmpty ? screenTime : '3.3h',
            color: AppTheme.softBlue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: '⚡',
            label: 'Time Saved',
            value: timeSaved.isNotEmpty ? timeSaved : '2h 14m',
            color: AppTheme.emerald,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyChartSection() {
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
          const Text(
            'Weekly Screen Time',
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Hours per day',
            style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        final idx = val.toInt();
                        if (idx >= 0 && idx < days.length) {
                          return Text(
                            days[idx],
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (val, _) {
                        if (val == 0 || val == 2 || val == 4 || val == 6 || val == 8) {
                          return Text(
                            '${val.toInt()}',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Screen Time Line (Red)
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 4.5),
                      FlSpot(1, 3.8),
                      FlSpot(2, 5.8),
                      FlSpot(3, 3.2),
                      FlSpot(4, 3.5),
                      FlSpot(5, 2.5),
                      FlSpot(6, 2.2),
                    ],
                    isCurved: true,
                    color: const Color(0xFFEF4444),
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                  ),
                  // Focus Time Line (Green)
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 2.0),
                      FlSpot(1, 2.5),
                      FlSpot(2, 3.0),
                      FlSpot(3, 3.5),
                      FlSpot(4, 3.2),
                      FlSpot(5, 4.5),
                      FlSpot(6, 4.8),
                    ],
                    isCurved: true,
                    color: AppTheme.emerald,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 12, height: 3, color: const Color(0xFFEF4444)),
              const SizedBox(width: 6),
              const Text('Screen Time', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(width: 20),
              Container(width: 12, height: 3, color: AppTheme.emerald),
              const SizedBox(width: 6),
              const Text('Focus Time', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMostUsedAppsSection() {
    final apps = [
      {'name': 'Instagram', 'icon': Icons.camera_alt_outlined, 'time': '1h 24m', 'pct': '34%', 'progress': 0.34, 'limited': true},
      {'name': 'YouTube', 'icon': Icons.play_circle_outline, 'time': '58m', 'pct': '23%', 'progress': 0.23, 'limited': true},
      {'name': 'WhatsApp', 'icon': Icons.chat_bubble_outline, 'time': '42m', 'pct': '17%', 'progress': 0.17, 'limited': false},
      {'name': 'TikTok', 'icon': Icons.music_note_outlined, 'time': '38m', 'pct': '15%', 'progress': 0.15, 'limited': true},
      {'name': 'Twitter', 'icon': Icons.flutter_dash, 'time': '22m', 'pct': '9%', 'progress': 0.09, 'limited': false},
      {'name': 'Games', 'icon': Icons.sports_esports_outlined, 'time': '8m', 'pct': '3%', 'progress': 0.03, 'limited': false},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Most Used Apps',
          style: TextStyle(
            fontFamily: 'Lora',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const Text(
          "Today's usage",
          style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 12),
        ...apps.map((app) {
          final isLimited = app['limited'] as bool;
          final pct = (app['progress'] as double);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.navySurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(app['icon'] as IconData, color: AppTheme.gold, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            app['name'] as String,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          if (isLimited) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'LIMITED',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 4,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(isLimited ? const Color(0xFFEF4444) : AppTheme.emerald),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      app['time'] as String,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    Text(
                      app['pct'] as String,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBlockedAppsSection(AsyncValue<List<dynamic>> appsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppTheme.textPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Blocked Apps',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Active restrictions',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddBlockedAppDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold.withOpacity(0.2),
                foregroundColor: AppTheme.gold,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add App', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        appsAsync.when(
          loading: () => const LoadingShimmer(height: 60),
          error: (_, __) => _buildDefaultBlockedApps(),
          data: (apps) {
            if (apps.isEmpty) return _buildDefaultBlockedApps();
            return Column(
              children: apps.map((app) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.camera_alt_outlined, color: AppTheme.gold, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          app.appName,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 18),
                        onPressed: () {
                          ref.read(focusRepositoryProvider).removeBlockedApp(app.id);
                          ref.invalidate(blockedAppsProvider);
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDefaultBlockedApps() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.navySurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              const Icon(Icons.camera_alt_outlined, color: AppTheme.gold, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Instagram',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        const Text('30 min', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.close, color: AppTheme.textMuted, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddBlockedAppDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navySurface,
        title: const Text('Add Blocked App'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'App name (e.g. TikTok)',
            hintStyle: TextStyle(color: AppTheme.textMuted),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(focusRepositoryProvider).addBlockedApp({
                  'app_name': controller.text,
                  'package_name': controller.text.toLowerCase().replaceAll(' ', '.'),
                });
                ref.invalidate(blockedAppsProvider);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add App'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon, label, value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
