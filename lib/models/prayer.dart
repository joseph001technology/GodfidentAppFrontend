class Prayer {
  final int id;
  final String prayerType;
  final String title;
  final String content;
  final String scripture;
  final String status;
  final String answeredNote;
  final bool isPrivate;
  final bool reminderEnabled;
  final int? category;
  final String? categoryName;
  final int timesPrayed;
  final String createdAt;
  final String updatedAt;
  final String? answeredAt;

  const Prayer({
    required this.id,
    required this.prayerType,
    required this.title,
    required this.content,
    this.scripture = '',
    this.status = 'active',
    this.answeredNote = '',
    this.isPrivate = true,
    this.reminderEnabled = false,
    this.category,
    this.categoryName,
    this.timesPrayed = 0,
    required this.createdAt,
    required this.updatedAt,
    this.answeredAt,
  });

  factory Prayer.fromJson(Map<String, dynamic> j) => Prayer(
        id: j['id'] ?? 0,
        prayerType: j['prayer_type'] ?? 'request',
        title: j['title'] ?? '',
        content: j['content'] ?? '',
        scripture: j['scripture'] ?? '',
        status: j['status'] ?? 'active',
        answeredNote: j['answered_note'] ?? '',
        isPrivate: j['is_private'] ?? true,
        reminderEnabled: j['reminder_enabled'] ?? false,
        category: j['category'],
        categoryName: j['category_name'],
        timesPrayed: j['times_prayed'] ?? 0,
        createdAt: j['created_at'] ?? '',
        updatedAt: j['updated_at'] ?? '',
        answeredAt: j['answered_at'],
      );

  bool get isAnswered => status == 'answered';
  bool get isActive => status == 'active';
}

class PrayerStats {
  final int total;
  final int active;
  final int answered;
  final double answerRate;
  final Map<String, int> byType;
  final int timesPrayed;

  const PrayerStats({
    required this.total,
    required this.active,
    required this.answered,
    required this.answerRate,
    required this.byType,
    required this.timesPrayed,
  });

  factory PrayerStats.fromJson(Map<String, dynamic> j) => PrayerStats(
        total: j['total'] ?? 0,
        active: j['active'] ?? 0,
        answered: j['answered'] ?? 0,
        answerRate: (j['answer_rate'] ?? 0.0).toDouble(),
        byType: Map<String, int>.from(j['by_type'] ?? {}),
        timesPrayed: j['times_prayed'] ?? 0,
      );
}
