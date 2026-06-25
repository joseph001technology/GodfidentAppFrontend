import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../models/analytics.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/common/app_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync    = ref.watch(dashboardProvider);
    final weeklyAsync  = ref.watch(weeklyReportProvider);
    final heatmapAsync = ref.watch(heatmapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(dashboardProvider);
              ref.invalidate(weeklyReportProvider);
              ref.invalidate(heatmapProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.gold,
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(weeklyReportProvider);
          ref.invalidate(heatmapProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Dashboard overview cards
            dashAsync.when(
              loading: () => const LoadingShimmer(height: 200),
              error: (e, _) => ErrorView(message: e.toString()),
              data: (dash) => _DashOverview(dash: dash),
            ),
            const SizedBox(height: 20),

            // Weekly bar chart
            const SectionHeader(title: 'THIS WEEK'),
            weeklyAsync.when(
              loading: () => const LoadingShimmer(height: 180),
              error: (_, __) => const SizedBox(),
              data: (weekly) => _WeeklyChart(weekly: weekly),
            ),
            const SizedBox(height: 20),

            // Heatmap
            const SectionHeader(title: 'READING HEATMAP (365 DAYS)'),
            heatmapAsync.when(
              loading: () => const LoadingShimmer(height: 120),
              error: (_, __) => const SizedBox(),
              data: (heatmap) => _HeatmapGrid(heatmap: heatmap),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _DashOverview extends StatelessWidget {
  final Dashboard dash;
  const _DashOverview({required this.dash});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          _StatCard(label: 'Current Streak', value: '${dash.reading.currentStreak}d', icon: Icons.local_fire_department, color: Colors.orange),
          const SizedBox(width: 10),
          _StatCard(label: 'Chapters/Week', value: '${dash.reading.chaptersThisWeek}', icon: Icons.menu_book_outlined, color: AppTheme.gold),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _StatCard(label: 'Total Prayers', value: '${dash.prayer.totalPrayers}', icon: Icons.volunteer_activism_outlined, color: Colors.pink),
          const SizedBox(width: 10),
          _StatCard(label: 'Answer Rate', value: '${dash.prayer.answerRate.toStringAsFixed(0)}%', icon: Icons.check_circle_outline, color: Colors.green),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _StatCard(label: 'Devotionals', value: '${dash.devotionals.totalRead}', icon: Icons.book_outlined, color: Colors.amber),
          const SizedBox(width: 10),
          _StatCard(label: 'AI Sessions', value: '${dash.study.aiSessions}', icon: Icons.auto_awesome_outlined, color: Colors.cyan),
        ]),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.navyOutline, width: 0.5),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final WeeklyReport weekly;
  const _WeeklyChart({required this.weekly});

  @override
  Widget build(BuildContext context) {
    final bars = weekly.days.map((d) => BarChartGroupData(
          x: weekly.days.indexOf(d),
          barRods: [
            BarChartRodData(
              toY: d.chaptersRead.toDouble(),
              color: d.isToday ? AppTheme.gold : AppTheme.gold.withOpacity(0.4),
              width: 22,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        )).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
        child: SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              barGroups: bars,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= weekly.days.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          weekly.days[idx].dayName.substring(0, 3),
                          style: TextStyle(
                            color: weekly.days[idx].isToday ? AppTheme.gold : Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeatmapGrid extends StatelessWidget {
  final Map<String, int> heatmap;
  const _HeatmapGrid({required this.heatmap});

  Color _cellColor(int count) {
    if (count == 0) return AppTheme.navyVariant;
    if (count == 1) return AppTheme.gold.withOpacity(0.3);
    if (count == 2) return AppTheme.gold.withOpacity(0.5);
    if (count <= 4) return AppTheme.gold.withOpacity(0.75);
    return AppTheme.gold;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 364));
    final days = List.generate(365, (i) => start.add(Duration(days: i)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(53, (week) {
                  return Column(
                    children: List.generate(7, (dow) {
                      final idx = week * 7 + dow;
                      if (idx >= days.length) return const SizedBox(width: 10, height: 10);
                      final day = days[idx];
                      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                      final count = heatmap[key] ?? 0;
                      return Container(
                        width: 9, height: 9,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: _cellColor(count),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              const Text('Less', style: TextStyle(color: Colors.grey, fontSize: 10)),
              const SizedBox(width: 6),
              ...[ 0, 1, 2, 3, 4].map((c) => Container(
                width: 10, height: 10,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(color: _cellColor(c), borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(width: 4),
              const Text('More', style: TextStyle(color: Colors.grey, fontSize: 10)),
            ]),
          ],
        ),
      ),
    );
  }
}
