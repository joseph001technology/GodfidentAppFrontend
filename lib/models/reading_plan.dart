class ReadingPlan {
  final int id;
  final String name;
  final String description;
  final String planType;
  final int durationDays;

  const ReadingPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.planType,
    required this.durationDays,
  });

  factory ReadingPlan.fromJson(Map<String, dynamic> j) => ReadingPlan(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        description: j['description'] ?? '',
        planType: j['plan_type'] ?? '',
        durationDays: j['duration_days'] ?? 0,
      );
}

class ReadingPlanDay {
  final int id;
  final int dayNumber;
  final String title;
  final List<Map<String, dynamic>> readings;

  const ReadingPlanDay({
    required this.id,
    required this.dayNumber,
    required this.title,
    required this.readings,
  });

  factory ReadingPlanDay.fromJson(Map<String, dynamic> j) => ReadingPlanDay(
        id: j['id'] ?? 0,
        dayNumber: j['day_number'] ?? 0,
        title: j['title'] ?? '',
        readings: List<Map<String, dynamic>>.from(j['readings'] ?? []),
      );

  String get readingsSummary =>
      readings.map((r) => '${r['book']} ${r['chapter_start']}').join(', ');
}

class UserReadingPlan {
  final int id;
  final ReadingPlan plan;
  final String status;
  final String startedAt;
  final String? completedAt;
  final int currentDay;
  final double progressPercent;
  final ReadingPlanDay? currentDayDetail;

  const UserReadingPlan({
    required this.id,
    required this.plan,
    required this.status,
    required this.startedAt,
    this.completedAt,
    required this.currentDay,
    required this.progressPercent,
    this.currentDayDetail,
  });

  factory UserReadingPlan.fromJson(Map<String, dynamic> j) => UserReadingPlan(
        id: j['id'] ?? 0,
        plan: ReadingPlan.fromJson(j['plan'] ?? {}),
        status: j['status'] ?? 'active',
        startedAt: j['started_at'] ?? '',
        completedAt: j['completed_at'],
        currentDay: j['current_day'] ?? 1,
        progressPercent: (j['progress_percent'] ?? 0.0).toDouble(),
        currentDayDetail: j['current_day_detail'] != null
            ? ReadingPlanDay.fromJson(j['current_day_detail'])
            : null,
      );

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isCompleted => status == 'completed';
}

class ReadingStreak {
  final int currentStreak;
  final int longestStreak;
  final String? lastReadDate;
  final int totalDaysRead;

  const ReadingStreak({
    required this.currentStreak,
    required this.longestStreak,
    this.lastReadDate,
    required this.totalDaysRead,
  });

  factory ReadingStreak.fromJson(Map<String, dynamic> j) => ReadingStreak(
        currentStreak: j['current_streak'] ?? 0,
        longestStreak: j['longest_streak'] ?? 0,
        lastReadDate: j['last_read_date'],
        totalDaysRead: j['total_days_read'] ?? 0,
      );
}
