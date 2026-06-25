import '../core/dio_client.dart';
import '../core/api_response.dart';
import '../models/notification.dart';

class NotificationRepository {
  final _dio = DioClient.instance;

  Future<List<AppNotification>> getList({bool unreadOnly = false}) async {
    final res = await _dio.get('/api/notifications/', queryParameters: {
      if (unreadOnly) 'unread': 'true',
    });
    final list = readList(res.data);
    return (list as List).map((j) => AppNotification.fromJson(j)).toList();
  }

  Future<void> markRead(int id) async {
    await _dio.post('/api/notifications/$id/mark_read/');
  }

  Future<void> markAllRead() async {
    await _dio.post('/api/notifications/mark_all_read/');
  }

  Future<int> getUnreadCount() async {
    final res = await _dio.get('/api/notifications/unread_count/');
    return res.data['count'] ?? 0;
  }
}
