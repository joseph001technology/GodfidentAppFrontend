import '../core/dio_client.dart';
import '../core/api_response.dart';
import '../models/activity.dart';
import '../models/analytics.dart';

class AnalyticsRepository {
  final _dio = DioClient.instance;

  Future<Dashboard> getDashboard() async {
    final res = await _dio.get('/api/analytics/dashboard/');
    return Dashboard.fromJson(readDataMap(res.data));
  }

  Future<Map<String, int>> getHeatmap({int days = 365}) async {
    final res = await _dio.get('/api/analytics/heatmap/', queryParameters: {'days': days});
    final raw = Map<String, dynamic>.from(readDataMap(res.data)['heatmap'] ?? {});
    return raw.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  /// The user's UTC offset in minutes, so the server groups activity by the
  /// user's own calendar day (a prayer at 01:00 in Nairobi belongs to that day).
  static int get _tzOffset => DateTime.now().timeZoneOffset.inMinutes;

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Real per-day activity between [start] and [end] (inclusive).
  Future<Map<String, DayActivity>> getActivity(DateTime start, DateTime end) async {
    final res = await _dio.get('/api/analytics/activity/', queryParameters: {
      'start': _ymd(start),
      'end': _ymd(end),
      'tz_offset': _tzOffset,
    });
    final raw = readDataMap(res.data)['days'];
    final out = <String, DayActivity>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) out['$k'] = DayActivity.fromJson(Map<String, dynamic>.from(v));
      });
    }
    return out;
  }

  Future<Overview> getOverview() async {
    final res = await _dio.get('/api/analytics/overview/', queryParameters: {'tz_offset': _tzOffset});
    return Overview.fromJson(readDataMap(res.data));
  }

  Future<WeeklyReport> getWeeklyReport() async {
    final res = await _dio.get('/api/analytics/weekly/');
    return WeeklyReport.fromJson(readDataMap(res.data));
  }

  Future<MonthlyReport> getMonthlyReport({int? year, int? month}) async {
    final res = await _dio.get('/api/analytics/monthly/', queryParameters: {
      if (year != null) 'year': year,
      if (month != null) 'month': month,
    });
    return MonthlyReport.fromJson(readDataMap(res.data));
  }

  Future<void> logReading({
    required String bookName,
    required int chapter,
    String translation = 'KJV',
  }) async {
    await _dio.post('/api/analytics/log-reading/', data: {
      'book_name': bookName,
      'chapter': chapter,
      'translation': translation,
    });
  }

  /// GET /api/analytics/focus/ — detailed focus-mode analytics.
  Future<Map<String, dynamic>> getFocusAnalytics() async {
    final res = await _dio.get('/api/analytics/focus/');
    return readDataMap(res.data);
  }

  /// GET /api/analytics/prayer/ — detailed prayer analytics.
  Future<Map<String, dynamic>> getPrayerAnalytics() async {
    final res = await _dio.get('/api/analytics/prayer/');
    return readDataMap(res.data);
  }

  /// GET /api/analytics/usage/ — app usage analytics.
  Future<Map<String, dynamic>> getUsageAnalytics() async {
    final res = await _dio.get('/api/analytics/usage/');
    return readDataMap(res.data);
  }

  /// POST /api/analytics/log-usage/ — log app usage.
  Future<void> logUsage({int screenTimeSeconds = 0, String mostVisitedPage = '', int sessionCount = 1}) async {
    await _dio.post('/api/analytics/log-usage/', data: {
      'screen_time_seconds': screenTimeSeconds,
      'most_visited_page': mostVisitedPage,
      'session_count': sessionCount,
    });
  }
}
