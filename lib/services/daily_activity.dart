import 'package:shared_preferences/shared_preferences.dart';

/// Remembers (on the phone, so it works offline) whether you have prayed or read
/// the Bible TODAY. The daily "you haven't prayed / read yet" nudges look at this
/// natively and stay silent when today is already done.
class DailyActivity {
  DailyActivity._();
  static const prayedKey = 'last_prayed_date';
  static const readKey = 'last_read_date';

  static String today({DateTime? at}) {
    final n = at ?? DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static Future<void> _mark(String key, [DateTime? on]) async {
    try {
      await (await SharedPreferences.getInstance()).setString(key, today(at: on));
    } catch (_) {}
  }

  /// [on] = the day a session STARTED: a session that runs past midnight (or is
  /// frozen overnight) still counts on the day it began.
  static Future<void> markPrayed({DateTime? on}) => _mark(prayedKey, on);
  static Future<void> markRead({DateTime? on}) => _mark(readKey, on);
}
