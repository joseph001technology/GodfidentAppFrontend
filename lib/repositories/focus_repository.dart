import '../core/dio_client.dart';
import '../core/api_response.dart';
import '../models/focus.dart';

class FocusRepository {
  final _dio = DioClient.instance;

  // ── Sessions ───────────────────────────────────────────────────
  Future<List<FocusSession>> getSessions({int? limit}) async {
    final res = await _dio.get('/api/focus/sessions/', queryParameters: {
      if (limit != null) 'limit': limit,
    });
    return (readList(res.data) as List).map((j) => FocusSession.fromJson(j)).toList();
  }

  Future<FocusSession> startSession() async {
    final res = await _dio.post('/api/focus/sessions/start/');
    return FocusSession.fromJson(res.data['data'] ?? res.data);
  }

  Future<FocusSession> endSession(int id, {int? durationMinutes, int? focusScore}) async {
    final res = await _dio.post('/api/focus/sessions/$id/end/', data: {
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (focusScore != null) 'focus_score': focusScore,
    });
    return FocusSession.fromJson(res.data['data'] ?? res.data);
  }

  // ── Blocked Apps ───────────────────────────────────────────────
  Future<List<BlockedApp>> getBlockedApps() async {
    final res = await _dio.get('/api/focus/blocked-apps/');
    return (readList(res.data) as List).map((j) => BlockedApp.fromJson(j)).toList();
  }

  Future<BlockedApp> addBlockedApp(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/focus/blocked-apps/', data: data);
    return BlockedApp.fromJson(res.data);
  }

  Future<void> removeBlockedApp(int id) async {
    await _dio.delete('/api/focus/blocked-apps/$id/');
  }

  // ── Blocked Websites ──────────────────────────────────────────
  Future<List<BlockedWebsite>> getBlockedWebsites() async {
    final res = await _dio.get('/api/focus/blocked-websites/');
    return (readList(res.data) as List).map((j) => BlockedWebsite.fromJson(j)).toList();
  }

  Future<BlockedWebsite> addBlockedWebsite(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/focus/blocked-websites/', data: data);
    return BlockedWebsite.fromJson(res.data);
  }

  Future<void> removeBlockedWebsite(int id) async {
    await _dio.delete('/api/focus/blocked-websites/$id/');
  }

  // ── Whitelist ─────────────────────────────────────────────────
  Future<List<WhitelistApp>> getWhitelistApps() async {
    final res = await _dio.get('/api/focus/whitelist-apps/');
    return (readList(res.data) as List).map((j) => WhitelistApp.fromJson(j)).toList();
  }

  Future<WhitelistApp> addWhitelistApp(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/focus/whitelist-apps/', data: data);
    return WhitelistApp.fromJson(res.data);
  }

  Future<void> removeWhitelistApp(int id) async {
    await _dio.delete('/api/focus/whitelist-apps/$id/');
  }

  Future<List<WhitelistWebsite>> getWhitelistWebsites() async {
    final res = await _dio.get('/api/focus/whitelist-websites/');
    return (readList(res.data) as List).map((j) => WhitelistWebsite.fromJson(j)).toList();
  }

  // ── Schedules ─────────────────────────────────────────────────
  Future<List<FocusSchedule>> getSchedules() async {
    final res = await _dio.get('/api/focus/schedules/');
    return (readList(res.data) as List).map((j) => FocusSchedule.fromJson(j)).toList();
  }

  Future<FocusSchedule> createSchedule(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/focus/schedules/', data: data);
    return FocusSchedule.fromJson(res.data);
  }

  Future<void> deleteSchedule(int id) async {
    await _dio.delete('/api/focus/schedules/$id/');
  }

  // ── Blocked Attempts ──────────────────────────────────────────
  Future<List<BlockedAttempt>> getBlockedAttempts({int? limit}) async {
    final res = await _dio.get('/api/focus/blocked-attempts/', queryParameters: {
      if (limit != null) 'limit': limit,
    });
    return (readList(res.data) as List).map((j) => BlockedAttempt.fromJson(j)).toList();
  }

  // ── Stats ─────────────────────────────────────────────────────
  Future<FocusStats> getStats() async {
    final res = await _dio.get('/api/focus/sessions/stats/');
    return FocusStats.fromJson(readDataMap(res.data));
  }
}
