import 'package:shared_preferences/shared_preferences.dart';

/// Remembers (on the phone, so it works offline) whether you have prayed or read
/// the Bible TODAY. The daily "you haven't prayed / read yet" nudges look at this
/// natively and stay silent when today is already done.
class DailyActivity {
  DailyActivity._();
  static const prayedKey = 'last_prayed_date';
  static const readKey = 'last_read_date';

  static String today() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static Future<void> _mark(String key) async {
    try {
      await (await SharedPreferences.getInstance()).setString(key, today());
    } catch (_) {}
  }

  static Future<void> markPrayed() => _mark(prayedKey);
  static Future<void> markRead() => _mark(readKey);
}
