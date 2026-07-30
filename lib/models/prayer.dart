class PrayerCategory {
  final int id;
  final String name;

  const PrayerCategory({required this.id, required this.name});

  factory PrayerCategory.fromJson(Map<String, dynamic> j) =>
      PrayerCategory(id: j['id'] ?? 0, name: j['name'] ?? '');
}

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
        timesPrayed: int.tryParse('${j['times_prayed'] ?? 0}') ?? 0,
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
        answerRate: (j['answer_rate'] ??
                ((j['total'] ?? 0) == 0
                    ? 0.0
                    : ((j['answered'] ?? 0) / (j['total'] ?? 1)) * 100))
            .toDouble(),
        byType: Map<String, int>.from(j['by_type'] ?? {}),
        timesPrayed: j['times_prayed'] ?? 0,
      );
}

/// A prayer session with timer tracking (from /api/prayer/sessions/).
class PrayerSession {
  final int id;
  final String title;
  final int durationMinutes;
  final int durationSeconds;
  final String notes;
  final bool isCompleted;
  final String startedAt;
  final String? endedAt;
  final String createdAt;

  const PrayerSession({
    required this.id,
    this.title = '',
    this.durationMinutes = 0,
    this.durationSeconds = 0,
    this.notes = '',
    this.isCompleted = false,
    required this.startedAt,
    this.endedAt,
    required this.createdAt,
  });

  factory PrayerSession.fromJson(Map<String, dynamic> j) => PrayerSession(
        id: j['id'] ?? 0,
        title: j['title'] ?? '',
        durationMinutes: j['duration_minutes'] ?? 0,
        durationSeconds: j['duration_seconds'] ?? 0,
        notes: j['notes'] ?? '',
        isCompleted: j['is_completed'] ?? false,
        startedAt: j['started_at'] ?? '',
        endedAt: j['ended_at'],
        createdAt: j['created_at'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        if (title.isNotEmpty) 'title': title,
        if (notes.isNotEmpty) 'notes': notes,
      };
}

/// A prayer log entry (from /api/prayer/logs/).
class PrayerLog {
  final int id;
  final int prayer;
  final String prayerTitle;
  final String note;
  final String prayedAt;

  const PrayerLog({
    required this.id,
    required this.prayer,
    this.prayerTitle = '',
    this.note = '',
    required this.prayedAt,
  });

  factory PrayerLog.fromJson(Map<String, dynamic> j) => PrayerLog(
        id: j['id'] ?? 0,
        prayer: j['prayer'] ?? 0,
        prayerTitle: j['prayer_title'] ?? '',
        note: j['note'] ?? '',
        prayedAt: j['prayed_at'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'prayer': prayer,
        if (note.isNotEmpty) 'note': note,
      };
}

/// A prayer timer log (from /api/prayer/timer-logs/).
class PrayerTimerLog {
  final int id;
  final int durationSeconds;
  final String startedAt;

  const PrayerTimerLog({
    required this.id,
    required this.durationSeconds,
    required this.startedAt,
  });

  factory PrayerTimerLog.fromJson(Map<String, dynamic> j) => PrayerTimerLog(
        id: j['id'] ?? 0,
        durationSeconds: j['duration_seconds'] ?? 0,
        startedAt: j['started_at'] ?? '',
      );

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m}m ${s}s';
  }
}

/// A personal prayer journal entry (from /api/prayer/journals/).
class PrayerJournal {
  final int id;
  final String title;
  final String content;
  final String scripture;
  final String mood;
  final bool isPrivate;
  final String createdAt;
  final String updatedAt;

  const PrayerJournal({
    required this.id,
    required this.title,
    required this.content,
    this.scripture = '',
    this.mood = '',
    this.isPrivate = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PrayerJournal.fromJson(Map<String, dynamic> j) => PrayerJournal(
        id: j['id'] ?? 0,
        title: j['title'] ?? '',
        content: j['content'] ?? '',
        scripture: j['scripture'] ?? '',
        mood: j['mood'] ?? '',
        isPrivate: j['is_private'] ?? true,
        createdAt: j['created_at'] ?? '',
        updatedAt: j['updated_at'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        if (scripture.isNotEmpty) 'scripture': scripture,
        if (mood.isNotEmpty) 'mood': mood,
        'is_private': isPrivate,
      };
}
