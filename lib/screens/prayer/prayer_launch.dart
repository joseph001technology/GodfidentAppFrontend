import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../services/daily_activity.dart';

/// Opens Prayer Focus and starts at once with [minutes] (the same value Prayer
/// Focus remembers as your last chosen time).
Future<void> startPrayerFocus(BuildContext context, int minutes) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setInt('prayer_focus_minutes', minutes);
  } catch (_) {}
  if (context.mounted) context.push('/prayer/focus?auto=1');
}

/// Opens the Prayer Focus screen so the person can choose a time themselves.
void openPrayerFocus(BuildContext context) => context.push('/prayer/focus');

/// A row of quick "start praying now" duration chips.
class PrayerDurationChips extends StatelessWidget {
  final List<int> minutes;
  final bool onDark;
  const PrayerDurationChips({super.key, this.minutes = const [5, 15, 30], this.onDark = true});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final m in minutes)
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => startPrayerFocus(context, m),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: onDark ? Colors.white.withValues(alpha: 0.10) : AppTheme.navyVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.goldLight.withValues(alpha: 0.6)),
            ),
            child: Text(
              m < 60 ? '$m min' : '1 hr',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: onDark ? AppTheme.goldLight : AppTheme.goldDark,
              ),
            ),
          ),
        ),
    ]);
  }
}

/// true when you have already prayed today (remembered on the phone, works offline).
Future<bool> prayedToday() async {
  try {
    final p = await SharedPreferences.getInstance();
    return p.getString(DailyActivity.prayedKey) == DailyActivity.today();
  } catch (_) {
    return false;
  }
}
