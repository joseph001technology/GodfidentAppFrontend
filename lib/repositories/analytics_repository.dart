import '../core/dio_client.dart';
import '../core/api_response.dart';
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
}
