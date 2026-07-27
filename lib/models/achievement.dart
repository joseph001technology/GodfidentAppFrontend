class Achievement {
  final int id;
  final String name;
  final String description;
  final String icon;
  final String category;
  final int requiredCount;
  final int xpReward;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    this.requiredCount = 1,
    this.xpReward = 0,
  });

  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        description: j['description'] ?? '',
        icon: j['icon'] ?? '🏆',
        category: j['category'] ?? 'general',
        requiredCount: j['required_count'] ?? 1,
        xpReward: j['xp_reward'] ?? 0,
      );
}

class UserAchievement {
  final int id;
  final Achievement achievement;
  final int progress;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final double progressPercent;
  final bool isRecent;

  const UserAchievement({
    required this.id,
    required this.achievement,
    this.progress = 0,
    this.isUnlocked = false,
    this.unlockedAt,
    this.progressPercent = 0.0,
    this.isRecent = false,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> j) => UserAchievement(
        id: j['id'] ?? 0,
        achievement: Achievement.fromJson(j['achievement'] ?? j),
        progress: j['progress'] ?? 0,
        isUnlocked: j['is_unlocked'] ?? false,
        unlockedAt: j['unlocked_at'] != null ? DateTime.parse(j['unlocked_at']) : null,
        progressPercent: (j['progress_percent'] ?? 0.0).toDouble(),
        isRecent: j['is_recent'] ?? false,
      );
}

class PrayerStreak {
  final int currentStreak;
  final int longestStreak;
  final String? lastPrayerDate;
  final int totalDaysPrayed;

  const PrayerStreak({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastPrayerDate,
    this.totalDaysPrayed = 0,
  });

  factory PrayerStreak.fromJson(Map<String, dynamic> j) => PrayerStreak(
        currentStreak: j['current_streak'] ?? 0,
        longestStreak: j['longest_streak'] ?? 0,
        lastPrayerDate: j['last_prayer_date'],
        totalDaysPrayed: j['total_days_prayed'] ?? 0,
      );
}

class ReadingGoal {
  final int id;
  final String goalType; // 'daily', 'weekly', 'yearly'
  final int target;
  final int progress;
  final String periodStart;
  final String? periodEnd;

  const ReadingGoal({
    required this.id,
    required this.goalType,
    required this.target,
    this.progress = 0,
    required this.periodStart,
    this.periodEnd,
  });

  factory ReadingGoal.fromJson(Map<String, dynamic> j) => ReadingGoal(
        id: j['id'] ?? 0,
        goalType: j['goal_type'] ?? 'daily',
        target: j['target'] ?? 0,
        progress: j['progress'] ?? 0,
        periodStart: j['period_start'] ?? '',
        periodEnd: j['period_end'],
      );

  double get progressPercent => target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;
}
