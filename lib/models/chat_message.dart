class ChatSession {
  final int id;
  final String title;
  final int messageCount;
  final List<ChatMessage> messages;
  final String createdAt;
  final String updatedAt;

  const ChatSession({
    required this.id,
    required this.title,
    required this.messageCount,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: j['id'] ?? 0,
        title: j['title'] ?? 'Chat',
        messageCount: j['message_count'] ?? 0,
        messages: (j['messages'] as List? ?? [])
            .map((m) => ChatMessage.fromJson(m))
            .toList(),
        createdAt: j['created_at'] ?? '',
        updatedAt: j['updated_at'] ?? '',
      );
}

class ChatMessage {
  final int id;
  final String role; // 'user' or 'assistant'
  final String content;
  final String createdAt;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] ?? 0,
        role: j['role'] ?? 'user',
        content: j['content'] ?? '',
        createdAt: j['created_at'] ?? '',
      );

  bool get isUser => role == 'user';
}

class StudySession {
  final int id;
  final String studyType;
  final String query;
  final String response;
  final String translation;
  final String createdAt;

  const StudySession({
    required this.id,
    required this.studyType,
    required this.query,
    required this.response,
    required this.translation,
    required this.createdAt,
  });

  factory StudySession.fromJson(Map<String, dynamic> j) => StudySession(
        id: j['id'] ?? 0,
        studyType: j['study_type'] ?? '',
        query: j['query'] ?? '',
        response: j['response'] ?? '',
        translation: j['translation'] ?? 'KJV',
        createdAt: j['created_at'] ?? '',
      );
}
