class AppNotification {
  final int id;
  final String notificationType;
  final String title;
  final String body;
  final bool isRead;
  final Map<String, dynamic> data;
  final String createdAt;
  final String? readAt;

  const AppNotification({
    required this.id,
    required this.notificationType,
    required this.title,
    required this.body,
    this.isRead = false,
    this.data = const {},
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] ?? 0,
        notificationType: j['notification_type'] ?? 'general',
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        isRead: j['is_read'] ?? false,
        data: Map<String, dynamic>.from(j['data'] ?? {}),
        createdAt: j['created_at'] ?? '',
        readAt: j['read_at'],
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        notificationType: notificationType,
        title: title,
        body: body,
        isRead: isRead ?? this.isRead,
        data: data,
        createdAt: createdAt,
        readAt: readAt,
      );
}
