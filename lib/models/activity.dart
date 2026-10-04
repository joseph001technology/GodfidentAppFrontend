/// What the user really did on one day (every number is a row count from the
/// server - nothing is estimated).
class DayActivity {
  final int chapters;
  final int prayers;
  final int devotionals;
  final int notes;
  final int rules;
  final int reminders;
  final int focusMinutes;
  final int focusSessions;
  final int total;

  const DayActivity({
    this.chapters = 0,
    this.prayers = 0,
    this.devotionals = 0,
    this.notes = 0,
    this.rules = 0,
    this.reminders = 0,
    this.focusMinutes = 0,
    this.focusSessions = 0,
    this.total = 0,
  });

  static const empty = DayActivity();

  factory DayActivity.fromJson(Map<String, dynamic> j) => DayActivity(
        chapters: (j['chapters'] as num?)?.toInt() ?? 0,
        prayers: (j['prayers'] as num?)?.toInt() ?? 0,
        devotionals: (j['devotionals'] as num?)?.toInt() ?? 0,
        notes: (j['notes'] as num?)?.toInt() ?? 0,
        rules: (j['rules'] as num?)?.toInt() ?? 0,
        reminders: (j['reminders'] as num?)?.toInt() ?? 0,
        focusMinutes: (j['focus_minutes'] as num?)?.toInt() ?? 0,
        focusSessions: (j['focus_sessions'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );

  bool get isEmpty => total == 0;
}

/// Numbers for the profile page and dashboard (GET /api/analytics/overview/).
class Overview {
  final int readingStreak;
  final int longestReadingStreak;
  final int chaptersTotal;
  final int chaptersThisWeek;
  final int chaptersThisMonth;
  final int completedSessions;
  final int protectedMinutes;
  final int protectedMinutesThisWeek;
  final int focusStreak;
  final int timesPrayed;
  final int notes;
  final int rulesDoneToday;
  final int remindersActive;
  final int remindersCompleted;
  final int devotionalsRead;
  final DateTime? memberSince;

  const Overview({
    this.readingStreak = 0,
    this.longestReadingStreak = 0,
    this.chaptersTotal = 0,
    this.chaptersThisWeek = 0,
    this.chaptersThisMonth = 0,
    this.completedSessions = 0,
    this.protectedMinutes = 0,
    this.protectedMinutesThisWeek = 0,
    this.focusStreak = 0,
    this.timesPrayed = 0,
    this.notes = 0,
    this.rulesDoneToday = 0,
    this.remindersActive = 0,
    this.remindersCompleted = 0,
    this.devotionalsRead = 0,
    this.memberSince,
  });

  static int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
  static Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  factory Overview.fromJson(Map<String, dynamic> j) {
    final r = _m(j['reading']), f = _m(j['focus']), p = _m(j['prayer']);
    return Overview(
      readingStreak: _i(r['current_streak']),
      longestReadingStreak: _i(r['longest_streak']),
      chaptersTotal: _i(r['chapters_total']),
      chaptersThisWeek: _i(r['chapters_this_week']),
      chaptersThisMonth: _i(r['chapters_this_month']),
      completedSessions: _i(f['completed_sessions']),
      protectedMinutes: _i(f['protected_minutes']),
      protectedMinutesThisWeek: _i(f['protected_minutes_this_week']),
      focusStreak: _i(f['current_streak']),
      timesPrayed: _i(p['times_prayed']),
      notes: _i(_m(j['notes'])['total']),
      rulesDoneToday: _i(_m(j['rules'])['completed_today']),
      remindersActive: _i(_m(j['reminders'])['active']),
      remindersCompleted: _i(_m(j['reminders'])['completed_total']),
      devotionalsRead: _i(_m(j['devotionals'])['total_read']),
      memberSince: DateTime.tryParse('${j['member_since'] ?? ''}'),
    );
  }

  /// "2h 15m" / "45m" / "0m".
  static String minutes(int m) => m < 60 ? '${m}m' : (m % 60 == 0 ? '${m ~/ 60}h' : '${m ~/ 60}h ${m % 60}m');
}
