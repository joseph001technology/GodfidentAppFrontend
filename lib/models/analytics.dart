class Dashboard {
  final ReadingStats reading;
  final PrayerDashStats prayer;
  final DevotionalStats devotionals;
  final StudyStats study;
  final PlanStats plans;
  final AnnotationStats annotations;

  const Dashboard({
    required this.reading,
    required this.prayer,
    required this.devotionals,
    required this.study,
    required this.plans,
    required this.annotations,
  });

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
        reading: ReadingStats.fromJson(j['reading'] ?? {}),
        prayer: PrayerDashStats.fromJson(j['prayer'] ?? {}),
        devotionals: DevotionalStats.fromJson(j['devotionals'] ?? {}),
        study: StudyStats.fromJson(j['study'] ?? {}),
        plans: PlanStats.fromJson(j['plans'] ?? {}),
        annotations: AnnotationStats.fromJson(j['annotations'] ?? {}),
      );
}

class ReadingStats {
  final Map<String, dynamic> streak;
  final int chaptersThisWeek;
  final int chaptersThisMonth;

  const ReadingStats({
    required this.streak,
    required this.chaptersThisWeek,
    required this.chaptersThisMonth,
  });

  factory ReadingStats.fromJson(Map<String, dynamic> j) => ReadingStats(
        streak: Map<String, dynamic>.from(j['streak'] ?? {}),
        chaptersThisWeek: j['chapters_this_week'] ?? 0,
        chaptersThisMonth: j['chapters_this_month'] ?? 0,
      );

  int get currentStreak => streak['current_streak'] ?? 0;
}

class PrayerDashStats {
  final int totalPrayers;
  final int answeredPrayers;
  final double answerRate;
  final int timesPrayed;

  const PrayerDashStats({
    required this.totalPrayers,
    required this.answeredPrayers,
    required this.answerRate,
    required this.timesPrayed,
  });

  factory PrayerDashStats.fromJson(Map<String, dynamic> j) => PrayerDashStats(
        totalPrayers: j['total_prayers'] ?? 0,
        answeredPrayers: j['answered_prayers'] ?? 0,
        answerRate: (j['answer_rate'] ?? 0.0).toDouble(),
        timesPrayed: j['times_prayed'] ?? 0,
      );
}

class DevotionalStats {
  final int totalRead;
  final int thisWeek;

  const DevotionalStats({required this.totalRead, required this.thisWeek});

  factory DevotionalStats.fromJson(Map<String, dynamic> j) => DevotionalStats(
        totalRead: j['total_read'] ?? 0,
        thisWeek: j['this_week'] ?? 0,
      );
}

class StudyStats {
  final int aiSessions;
  const StudyStats({required this.aiSessions});
  factory StudyStats.fromJson(Map<String, dynamic> j) =>
      StudyStats(aiSessions: j['ai_sessions'] ?? 0);
}

class PlanStats {
  final int active;
  final int completed;
  const PlanStats({required this.active, required this.completed});
  factory PlanStats.fromJson(Map<String, dynamic> j) =>
      PlanStats(active: j['active'] ?? 0, completed: j['completed'] ?? 0);
}

class AnnotationStats {
  final int bookmarks;
  final int highlights;
  const AnnotationStats({required this.bookmarks, required this.highlights});
  factory AnnotationStats.fromJson(Map<String, dynamic> j) =>
      AnnotationStats(bookmarks: j['bookmarks'] ?? 0, highlights: j['highlights'] ?? 0);
}

class WeeklyReport {
  final String weekStart;
  final String weekEnd;
  final List<DayReport> days;
  final Map<String, int> totals;

  const WeeklyReport({
    required this.weekStart,
    required this.weekEnd,
    required this.days,
    required this.totals,
  });

  factory WeeklyReport.fromJson(Map<String, dynamic> j) => WeeklyReport(
        weekStart: j['week_start'] ?? '',
        weekEnd: j['week_end'] ?? '',
        days: (j['days'] as List? ?? []).map((d) => DayReport.fromJson(d)).toList(),
        totals: Map<String, int>.from(j['totals'] ?? {}),
      );
}

class DayReport {
  final String date;
  final String dayName;
  final int chaptersRead;
  final int prayersLogged;
  final int devotionalsRead;
  final bool isToday;

  const DayReport({
    required this.date,
    required this.dayName,
    required this.chaptersRead,
    required this.prayersLogged,
    required this.devotionalsRead,
    required this.isToday,
  });

  factory DayReport.fromJson(Map<String, dynamic> j) => DayReport(
        date: j['date'] ?? '',
        dayName: j['day_name'] ?? '',
        chaptersRead: j['chapters_read'] ?? 0,
        prayersLogged: j['prayers_logged'] ?? 0,
        devotionalsRead: j['devotionals_read'] ?? 0,
        isToday: j['is_today'] ?? false,
      );
}
