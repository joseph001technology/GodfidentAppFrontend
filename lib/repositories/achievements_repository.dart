import '../core/dio_client.dart';
import '../core/api_response.dart';
import '../models/achievement.dart';

class AchievementsRepository {
  final _dio = DioClient.instance;

  Future<List<Achievement>> getAll() async {
    final res = await _dio.get('/api/achievements/all/');
    return (readList(res.data) as List).map((j) => Achievement.fromJson(j)).toList();
  }

  Future<List<UserAchievement>> getUserAchievements() async {
    final res = await _dio.get('/api/achievements/');
    return (readList(res.data) as List).map((j) => UserAchievement.fromJson(j)).toList();
  }

  Future<List<UserAchievement>> getRecent({int? limit}) async {
    final res = await _dio.get('/api/achievements/recent/', queryParameters: {
      if (limit != null) 'limit': limit,
    });
    return (readList(res.data) as List).map((j) => UserAchievement.fromJson(j)).toList();
  }

  // Prayer streak from prayer app
  Future<PrayerStreak> getPrayerStreak() async {
    final res = await _dio.get('/api/prayer/streak/');
    return PrayerStreak.fromJson(readDataMap(res.data));
  }
}
