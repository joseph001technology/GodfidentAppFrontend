class FocusSession {
  final int id;
  final DateTime? startTime;
  final DateTime? endTime;
  final int durationMinutes;
  final int focusScore;
  final bool isActive;
  final String createdAt;

  const FocusSession({
    required this.id,
    this.startTime,
    this.endTime,
    this.durationMinutes = 0,
    this.focusScore = 0,
    this.isActive = false,
    required this.createdAt,
  });

  factory FocusSession.fromJson(Map<String, dynamic> j) => FocusSession(
        id: j['id'] ?? 0,
        startTime: j['start_time'] != null ? DateTime.parse(j['start_time']) : null,
        endTime: j['end_time'] != null ? DateTime.parse(j['end_time']) : null,
        durationMinutes: j['duration_minutes'] ?? 0,
        focusScore: j['focus_score'] ?? 0,
        isActive: j['is_active'] ?? false,
        createdAt: j['created_at'] ?? '',
      );
}

class BlockedApp {
  final int id;
  final String appName;
  final String packageName;
  final String? icon;

  const BlockedApp({
    required this.id,
    required this.appName,
    required this.packageName,
    this.icon,
  });

  factory BlockedApp.fromJson(Map<String, dynamic> j) => BlockedApp(
        id: j['id'] ?? 0,
        appName: j['app_name'] ?? '',
        packageName: j['package_name'] ?? '',
        icon: j['icon'],
      );

  Map<String, dynamic> toJson() => {
        'app_name': appName,
        'package_name': packageName,
        if (icon != null) 'icon': icon,
      };
}

class BlockedWebsite {
  final int id;
  final String url;
  final String? domain;

  const BlockedWebsite({required this.id, required this.url, this.domain});

  factory BlockedWebsite.fromJson(Map<String, dynamic> j) => BlockedWebsite(
        id: j['id'] ?? 0,
        url: j['url'] ?? '',
        domain: j['domain'],
      );

  Map<String, dynamic> toJson() => {'url': url, if (domain != null) 'domain': domain};
}

class FocusSchedule {
  final int id;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final bool isActive;

  const FocusSchedule({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
  });

  factory FocusSchedule.fromJson(Map<String, dynamic> j) => FocusSchedule(
        id: j['id'] ?? 0,
        dayOfWeek: j['day_of_week'] ?? '',
        startTime: j['start_time'] ?? '',
        endTime: j['end_time'] ?? '',
        isActive: j['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'is_active': isActive,
      };
}

class FocusStats {
  final int totalSessions;
  final int totalFocusMinutes;
  final double averageFocusScore;
  final int currentStreak;
  final int longestStreak;
  final int timeSavedMinutes;

  const FocusStats({
    this.totalSessions = 0,
    this.totalFocusMinutes = 0,
    this.averageFocusScore = 0.0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.timeSavedMinutes = 0,
  });

  factory FocusStats.fromJson(Map<String, dynamic> j) => FocusStats(
        totalSessions: j['total_sessions'] ?? 0,
        totalFocusMinutes: j['total_focus_minutes'] ?? 0,
        averageFocusScore: (j['average_focus_score'] ?? 0.0).toDouble(),
        currentStreak: j['current_streak'] ?? 0,
        longestStreak: j['longest_streak'] ?? 0,
        timeSavedMinutes: j['time_saved_minutes'] ?? 0,
      );
}

class BlockedAttempt {
  final int id;
  final String appName;
  final String? websiteUrl;
  final DateTime blockedAt;
  final String scripture;

  const BlockedAttempt({
    required this.id,
    required this.appName,
    this.websiteUrl,
    required this.blockedAt,
    required this.scripture,
  });

  factory BlockedAttempt.fromJson(Map<String, dynamic> j) => BlockedAttempt(
        id: j['id'] ?? 0,
        appName: j['app_name'] ?? '',
        websiteUrl: j['website_url'],
        blockedAt: DateTime.parse(j['blocked_at'] ?? DateTime.now().toIso8601String()),
        scripture: j['scripture'] ?? '"Set a guard over my mouth, Lord; keep watch over the door of my lips." — Psalm 141:3',
      );
}

class UsageStats {
  final String date;
  final int screenTimeMinutes;
  final int focusTimeMinutes;
  final Map<String, int> appUsage; // app_name -> minutes

  const UsageStats({
    required this.date,
    this.screenTimeMinutes = 0,
    this.focusTimeMinutes = 0,
    this.appUsage = const {},
  });

  factory UsageStats.fromJson(Map<String, dynamic> j) => UsageStats(
        date: j['date'] ?? '',
        screenTimeMinutes: j['screen_time_minutes'] ?? 0,
        focusTimeMinutes: j['focus_time_minutes'] ?? 0,
        appUsage: Map<String, int>.from(j['app_usage'] ?? {}),
      );
}

class WhitelistApp {
  final int id;
  final String appName;
  final String packageName;

  const WhitelistApp({required this.id, required this.appName, required this.packageName});

  factory WhitelistApp.fromJson(Map<String, dynamic> j) => WhitelistApp(
        id: j['id'] ?? 0,
        appName: j['app_name'] ?? '',
        packageName: j['package_name'] ?? '',
      );

  Map<String, dynamic> toJson() => {'app_name': appName, 'package_name': packageName};
}

class WhitelistWebsite {
  final int id;
  final String url;
  final String? domain;

  const WhitelistWebsite({required this.id, required this.url, this.domain});

  factory WhitelistWebsite.fromJson(Map<String, dynamic> j) => WhitelistWebsite(
        id: j['id'] ?? 0,
        url: j['url'] ?? '',
        domain: j['domain'],
      );

  Map<String, dynamic> toJson() => {'url': url, if (domain != null) 'domain': domain};
}
