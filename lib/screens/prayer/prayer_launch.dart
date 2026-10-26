import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../services/daily_activity.dart';
import '../../services/focus_session_manager.dart';
import '../../services/session_ticker.dart';

bool _addingPrayerTime = false; // a quick double tap must not start (or add) twice

/// Prayer time from the Prayer page. There is one Focus for everything:
/// with nothing running it starts a normal Focus session of [minutes]; with a
/// session running or frozen it adds [minutes] to that session.
Future<void> startPrayerFocus(BuildContext context, int minutes) async {
  if (_addingPrayerTime) return;
  _addingPrayerTime = true;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final r = await SessionManager.instance.addPrayerTime(minutes);
    await SessionTicker.instance.refresh();
    messenger.showSnackBar(SnackBar(content: Text(r.message)));
  } finally {
    _addingPrayerTime = false;
  }
}

/// Opens the Focus page so the person can choose a time themselves.
void openPrayerFocus(BuildContext context) => context.push('/prayer/focus');

/// A row of quick duration chips. With no session they read "5 min" and start
/// one; while a session is running or frozen they read "+5 min" and add time.
class PrayerDurationChips extends StatelessWidget {
  final List<int> minutes;
  const PrayerDurationChips({super.key, this.minutes = const [5, 15, 30]});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SessionSnapshot>(
      valueListenable: SessionTicker.instance,
      builder: (context, snap, _) {
        final adding = snap.active;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in minutes)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => startPrayerFocus(context, m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: AppTheme.isDark ? 0.16 : 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.heroAccent.withValues(alpha: 0.6)),
                ),
                child: Text(
                  adding ? '+$m min' : (m < 60 ? '$m min' : '1 hr'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.heroAccent,
                  ),
                ),
              ),
            ),
        ]);
      },
    );
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
