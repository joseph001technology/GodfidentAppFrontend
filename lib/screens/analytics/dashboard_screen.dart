import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/activity.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/common/app_widgets.dart';

/// "My Activity": a real picture of what you actually did with God.
///
/// Every number comes from the server (counts of real rows): Bible chapters
/// opened, completed Focus sessions and protected minutes, prayers, notes,
/// rules and reminders you finished. Nothing is sample data, and anything
/// that is not part of the app (AI sessions, "answer rate") is gone.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  bool get _isCurrentMonth {
    final n = DateTime.now();
    return _month.year == n.year && _month.month == n.month;
  }

  Future<void> _refresh() async {
    ref.invalidate(overviewProvider);
    ref.invalidate(recentActivityProvider);
    ref.invalidate(monthActivityProvider);
    await ref.read(overviewProvider.future).catchError((_) => const Overview());
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(overviewProvider);
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        title: Text('My Activity',
            style: TextStyle(fontFamily: 'Lora', fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.ink)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh)],
      ),
      body: RefreshIndicator(
        color: AppTheme.gold,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            overview.when(
              loading: () => const LoadingShimmer(height: 190),
              error: (e, _) => ErrorView(message: friendlyError(e), onRetry: () => ref.invalidate(overviewProvider)),
              data: (o) => _Summary(o: o),
            ),
            const SizedBox(height: 22),
            _title('Last 7 days'),
            const SizedBox(height: 10),
            _weekCard(),
            const SizedBox(height: 22),
            _calendarHeader(),
            const SizedBox(height: 10),
            _calendarCard(),
          ],
        ),
      ),
    );
  }

  Widget _title(String t) => Text(t,
      style: TextStyle(fontFamily: 'Lora', fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.ink));

  // ── last 7 days ────────────────────────────────────────────────────
  Widget _weekCard() {
    final async = ref.watch(recentActivityProvider);
    return _card(
      child: async.when(
        loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(color: AppTheme.gold))),
        error: (e, _) => Text(friendlyError(e), style: TextStyle(color: AppTheme.textSecondary)),
        data: (map) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
          final values = [for (final d in days) (map[_key(d)]?.total ?? 0).toDouble()];
          final total = values.fold<double>(0, (a, b) => a + b);
          if (total == 0) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Nothing recorded this week yet.\nRead a chapter or start a Focus session and it will show here.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, height: 1.4)),
              ),
            );
          }
          const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          final maxY = (values.reduce((a, b) => a > b ? a : b) + 1).ceilToDouble();
          return SizedBox(
            height: 170,
            child: BarChart(BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY <= 4 ? 1 : (maxY / 4).ceilToDouble(),
                getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.navyOutline, strokeWidth: 0.6),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (g, _, rod, __) => BarTooltipItem(
                    '${rod.toY.toInt()} ${rod.toY == 1 ? 'activity' : 'activities'}',
                    const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: maxY <= 4 ? 1 : (maxY / 4).ceilToDouble(),
                    getTitlesWidget: (v, _) =>
                        Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= days.length) return const SizedBox();
                      final isToday = i == days.length - 1;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(names[days[i].weekday - 1],
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                                color: isToday ? AppTheme.goldDark : AppTheme.textMuted)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < values.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: values[i],
                      width: 20,
                      color: i == values.length - 1 ? AppTheme.gold : AppTheme.gold.withValues(alpha: 0.45),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ]),
              ],
            )),
          );
        },
      ),
    );
  }

  // ── month calendar ─────────────────────────────────────────────────
  Widget _calendarHeader() {
    return Row(children: [
      Expanded(child: _title('${_months[_month.month - 1]} ${_month.year}')),
      IconButton(
        tooltip: 'Previous month',
        onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1, 1)),
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        tooltip: 'Next month',
        onPressed: _isCurrentMonth ? null : () => setState(() => _month = DateTime(_month.year, _month.month + 1, 1)),
        icon: const Icon(Icons.chevron_right),
      ),
    ]);
  }

  Widget _calendarCard() {
    final async = ref.watch(monthActivityProvider(_month));
    return _card(
      child: async.when(
        loading: () => const SizedBox(height: 260, child: Center(child: CircularProgressIndicator(color: AppTheme.gold))),
        error: (e, _) => ErrorView(message: friendlyError(e), onRetry: () => ref.invalidate(monthActivityProvider(_month))),
        data: (map) => _calendarGrid(map),
      ),
    );
  }

  Widget _calendarGrid(Map<String, DayActivity> map) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = DateTime(_month.year, _month.month, 1).weekday - 1; // Monday first
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activeDays = map.values.where((a) => !a.isEmpty).length;
    final monthTotal = map.values.fold<int>(0, (a, b) => a + b.total);
    final focusMin = map.values.fold<int>(0, (a, b) => a + b.focusMinutes);

    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _dayCell(DateTime(_month.year, _month.month, d), map[_key(DateTime(_month.year, _month.month, d))], today),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        for (final n in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
          Expanded(
            child: Center(
              child: Text(n, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
            ),
          ),
      ]),
      const SizedBox(height: 6),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
        children: cells,
      ),
      const SizedBox(height: 14),
      Row(children: [
        _legend(AppTheme.gold, 'Bible'),
        _legend(AppTheme.emerald, 'Focus'),
        _legend(AppTheme.accentPurple, 'Prayer'),
        _legend(AppTheme.softBlue, 'Other'),
      ]),
      const Divider(height: 24),
      Text(
        activeDays == 0
            ? 'No activity recorded this month.'
            : '$activeDays active day${activeDays == 1 ? '' : 's'} · $monthTotal ${monthTotal == 1 ? 'activity' : 'activities'}'
                '${focusMin > 0 ? ' · ${Overview.minutes(focusMin)} protected for God' : ''}',
        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
      ),
    ]);
  }

  Widget _legend(Color c, String label) => Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ]),
      );

  Widget _dayCell(DateTime day, DayActivity? a, DateTime today) {
    final total = a?.total ?? 0;
    final isToday = day == today;
    final future = day.isAfter(today);
    final fill = total == 0
        ? AppTheme.navyVariant.withValues(alpha: future ? 0.35 : 0.9)
        : AppTheme.gold.withValues(alpha: total >= 7 ? 0.75 : total >= 4 ? 0.5 : total >= 2 ? 0.32 : 0.18);

    final dots = <Color>[
      if ((a?.chapters ?? 0) > 0) AppTheme.gold,
      if ((a?.focusSessions ?? 0) > 0) AppTheme.emerald,
      if ((a?.prayers ?? 0) > 0) AppTheme.accentPurple,
      if (((a?.notes ?? 0) + (a?.rules ?? 0) + (a?.reminders ?? 0) + (a?.devotionals ?? 0)) > 0) AppTheme.softBlue,
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: future ? null : () => _showDay(day, a ?? DayActivity.empty),
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isToday ? AppTheme.ink : Colors.transparent, width: 1.6),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${day.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: total > 0 || isToday ? FontWeight.w800 : FontWeight.w500,
                color: future ? AppTheme.textMuted.withValues(alpha: 0.5) : AppTheme.ink,
              )),
          const SizedBox(height: 3),
          SizedBox(
            height: 6,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final c in dots.take(4))
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _showDay(DateTime day, DayActivity a) {
    const wd = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final rows = <(IconData, Color, String)>[
      if (a.chapters > 0) (Icons.menu_book, AppTheme.gold, '${a.chapters} Bible chapter${a.chapters == 1 ? '' : 's'} read'),
      if (a.focusSessions > 0)
        (Icons.shield, AppTheme.emerald,
            '${a.focusSessions} Focus session${a.focusSessions == 1 ? '' : 's'} · ${Overview.minutes(a.focusMinutes)} protected'),
      if (a.prayers > 0) (Icons.volunteer_activism, AppTheme.accentPurple, '${a.prayers} prayer${a.prayers == 1 ? '' : 's'} prayed'),
      if (a.devotionals > 0) (Icons.auto_stories, AppTheme.softBlue, '${a.devotionals} devotional${a.devotionals == 1 ? '' : 's'} read'),
      if (a.notes > 0) (Icons.edit_note, AppTheme.softBlue, '${a.notes} note${a.notes == 1 ? '' : 's'} written'),
      if (a.rules > 0) (Icons.rule, AppTheme.softBlue, '${a.rules} rule${a.rules == 1 ? '' : 's'} kept'),
      if (a.reminders > 0) (Icons.alarm_on, AppTheme.softBlue, '${a.reminders} reminder${a.reminders == 1 ? '' : 's'} completed'),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.navySurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${wd[day.weekday - 1]}, ${day.day} ${_months[day.month - 1]}',
                style: const TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Text('Nothing was recorded on this day.', style: TextStyle(color: AppTheme.textSecondary))
            else
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: r.$2.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                      child: Icon(r.$1, size: 18, color: r.$2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(r.$3, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ]),
                ),
          ]),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.navyOutline),
        ),
        child: child,
      );

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// The four headline numbers - all real.
class _Summary extends StatelessWidget {
  final Overview o;
  const _Summary({required this.o});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        _tile(Icons.local_fire_department, AppTheme.gold, '${o.readingStreak}', o.readingStreak == 1 ? 'day Bible streak' : 'day Bible streak'),
        const SizedBox(width: 12),
        _tile(Icons.shield, AppTheme.emerald, Overview.minutes(o.protectedMinutes), 'protected for God'),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _tile(Icons.check_circle_outline, AppTheme.emerald, '${o.completedSessions}',
            o.completedSessions == 1 ? 'Focus session completed' : 'Focus sessions completed'),
        const SizedBox(width: 12),
        _tile(Icons.menu_book_outlined, AppTheme.gold, '${o.chaptersThisWeek}', 'chapters this week'),
      ]),
    ]);
  }

  Widget _tile(IconData icon, Color color, String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.navySurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontFamily: 'Lora', fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.ink)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ]),
        ),
      );
}
