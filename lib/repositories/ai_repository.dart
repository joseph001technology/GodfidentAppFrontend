import '../core/dio_client.dart';
import '../core/api_response.dart';
import '../models/chat_message.dart';

class AiRepository {
  final _dio = DioClient.instance;

  Future<Map<String, dynamic>> chat({
    required String message,
    int? sessionId,
  }) async {
    final res = await _dio.post('/api/ai/chat/', data: {
      'message': message,
      if (sessionId != null) 'session_id': sessionId,
    });
    return {
      'session_id': res.data['session_id'],
      'response': res.data['response'] ?? '',
    };
  }

  Future<String> explainVerse({
    required String reference,
    String translation = 'KJV',
    String verseText = '',
  }) async {
    final res = await _dio.post('/api/ai/explain-verse/', data: {
      'reference': reference,
      'translation': translation,
      if (verseText.isNotEmpty) 'verse_text': verseText,
    });
    return res.data['explanation'] ?? '';
  }

  Future<String> explainChapter({
    required String book,
    required int chapter,
    String translation = 'KJV',
  }) async {
    final res = await _dio.post('/api/ai/explain-chapter/', data: {
      'book': book,
      'chapter': chapter,
      'translation': translation,
    });
    return res.data['study'] ?? '';
  }

  Future<String> topicStudy(String topic) async {
    final res = await _dio.post('/api/ai/topic-study/', data: {'topic': topic});
    return res.data['study'] ?? '';
  }

  Future<String> characterStudy(String character) async {
    final res = await _dio.post('/api/ai/character-study/', data: {'character': character});
    return res.data['study'] ?? '';
  }

  Future<String> dailyEncouragement() async {
    final res = await _dio.get('/api/ai/daily-encouragement/');
    return res.data['encouragement'] ?? '';
  }

  Future<String> prayerAssistance({
    required String topic,
    String scripture = '',
  }) async {
    final res = await _dio.post('/api/ai/prayer-assistance/', data: {
      'topic': topic,
      if (scripture.isNotEmpty) 'scripture': scripture,
    });
    return res.data['guidance'] ?? '';
  }

  Future<List<StudySession>> getStudyHistory({String? type}) async {
    final res = await _dio.get('/api/ai/study-history/', queryParameters: {
      if (type != null) 'type': type,
    });
    final list = readList(res.data);
    return (list as List).map((j) => StudySession.fromJson(j)).toList();
  }

  Future<List<ChatSession>> getSessions() async {
    final res = await _dio.get('/api/ai/sessions/');
    final list = readList(res.data);
    return (list as List).map((j) => ChatSession.fromJson(j)).toList();
  }

  Future<ChatSession> getSession(int id) async {
    final res = await _dio.get('/api/ai/sessions/$id/');
    return ChatSession.fromJson(readMap(res.data));
  }

  Future<void> deleteSession(int id) async {
    await _dio.delete('/api/ai/sessions/$id/');
  }
}
