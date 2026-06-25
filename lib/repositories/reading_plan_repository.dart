import '../core/dio_client.dart';
import '../core/api_response.dart';
import '../models/reading_plan.dart';

class ReadingPlanRepository {
  final _dio = DioClient.instance;

  Future<List<ReadingPlan>> getPlans() async {
    final res = await _dio.get('/api/reading-plans/plans/');
    final list = readList(res.data);
    return (list as List).map((j) => ReadingPlan.fromJson(j)).toList();
  }

  Future<List<ReadingPlanDay>> getPlanDays(int planId) async {
    final res = await _dio.get('/api/reading-plans/plans/$planId/days/');
    final list = readList(res.data);
    return (list as List).map((j) => ReadingPlanDay.fromJson(j)).toList();
  }

  Future<List<UserReadingPlan>> getMyPlans() async {
    final res = await _dio.get('/api/reading-plans/my-plans/');
    final list = readList(res.data);
    return (list as List).map((j) => UserReadingPlan.fromJson(j)).toList();
  }

  Future<UserReadingPlan> enroll(int planId) async {
    final res = await _dio.post('/api/reading-plans/my-plans/', data: {'plan_id': planId});
    return UserReadingPlan.fromJson(res.data);
  }

  Future<void> completeDay(int userPlanId, {int? dayNumber}) async {
    await _dio.post('/api/reading-plans/my-plans/$userPlanId/complete_day/', data: {
      if (dayNumber != null) 'day_number': dayNumber,
    });
  }

  Future<void> pause(int userPlanId) async {
    await _dio.post('/api/reading-plans/my-plans/$userPlanId/pause/');
  }

  Future<void> resume(int userPlanId) async {
    await _dio.post('/api/reading-plans/my-plans/$userPlanId/resume/');
  }

  Future<ReadingStreak> getStreak() async {
    final res = await _dio.get('/api/reading-plans/streak/');
    return ReadingStreak.fromJson(res.data['data']);
  }
}
