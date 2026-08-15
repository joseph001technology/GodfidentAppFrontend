class ReminderCategory {
  final int id;
  final String name;
  final String? color;
  final String? icon;

  const ReminderCategory({required this.id, required this.name, this.color, this.icon});

  factory ReminderCategory.fromJson(Map<String, dynamic> j) => ReminderCategory(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        color: j['color'],
        icon: j['icon'],
      );

  Map<String, dynamic> toJson() => {'name': name, if (color != null) 'color': color, if (icon != null) 'icon': icon};
}

class Reminder {
  final int id;
  final String title;
  final String? description;
  final bool isCompleted;
  final bool isSnoozed;
  final bool isEnabled;
  final bool isAlarm;
  final String targetPage; // 'prayer', 'bible', 'notes', 'devotional', 'general'
  final String date;
  final String? time;
  final String repeat; // 'none', 'once', 'daily', 'weekly'
  final String? repeatUntil;
  final int? snoozeMinutes;
  final int? category;
  final String? categoryName;
  final String? categoryColor;
  final String createdAt;
  final String? completedAt;

  const Reminder({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.isSnoozed = false,
    this.isEnabled = true,
    this.isAlarm = false,
    this.targetPage = 'general',
    required this.date,
    this.time,
    this.repeat = 'none',
    this.repeatUntil,
    this.snoozeMinutes,
    this.category,
    this.categoryName,
    this.categoryColor,
    required this.createdAt,
    this.completedAt,
  });

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'] ?? 0,
        title: j['title'] ?? '',
        description: j['description'],
        isCompleted: j['is_completed'] ?? false,
        isSnoozed: j['is_snoozed'] ?? false,
        isEnabled: j['is_enabled'] ?? true,
        isAlarm: j['is_alarm'] ?? false,
        targetPage: j['target_page'] ?? 'general',
        date: j['date'] ?? '',
        time: j['time'],
        repeat: j['repeat'] ?? 'none',
        repeatUntil: j['repeat_until'],
        snoozeMinutes: j['snooze_minutes'],
        category: j['category'],
        categoryName: j['category_name'],
        categoryColor: j['category_color'],
        createdAt: j['created_at'] ?? '',
        completedAt: j['completed_at'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (description != null) 'description': description,
        'is_completed': isCompleted,
        'is_snoozed': isSnoozed,
        'is_enabled': isEnabled,
        'is_alarm': isAlarm,
        'target_page': targetPage,
        'date': date,
        if (time != null) 'time': time,
        'repeat': repeat,
        if (repeatUntil != null) 'repeat_until': repeatUntil,
        if (category != null) 'category': category,
        'created_at': createdAt,
      };

  Reminder copyWith({
    bool? isCompleted,
    bool? isSnoozed,
    bool? isEnabled,
    bool? isAlarm,
    String? title,
    String? description,
    String? date,
    String? time,
    String? repeat,
    String? targetPage,
  }) =>
      Reminder(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        isCompleted: isCompleted ?? this.isCompleted,
        isSnoozed: isSnoozed ?? this.isSnoozed,
        isEnabled: isEnabled ?? this.isEnabled,
        isAlarm: isAlarm ?? this.isAlarm,
        targetPage: targetPage ?? this.targetPage,
        date: date ?? this.date,
        time: time ?? this.time,
        repeat: repeat ?? this.repeat,
        repeatUntil: repeatUntil,
        snoozeMinutes: snoozeMinutes,
        category: category,
        categoryName: categoryName,
        categoryColor: categoryColor,
        createdAt: createdAt,
        completedAt: completedAt,
      );

  DateTime? get dateTime {
    if (date.isEmpty) return null;
    try {
      if (time != null && time!.isNotEmpty) {
        return DateTime.parse('${date}T$time');
      }
      return DateTime.parse(date);
    } catch (_) {
      return null;
    }
  }

  /// Returns a human-readable time string, e.g. "9:30 AM" or empty string
  String get formattedTime {
    if (time == null || time!.isEmpty) return '';
    try {
      final parts = time!.split(':');
      if (parts.length < 2) return time!;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '${displayHour}:${minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return time!;
    }
  }

  String get nextOccurrenceText {
    if (time == null || time!.isEmpty) return 'Today';
    if (repeat == 'daily') return 'Daily at $formattedTime';
    if (repeat == 'weekly') return 'Weekly at $formattedTime';
    return '$date at $formattedTime';
  }

  String get targetRoute {
    switch (targetPage.toLowerCase()) {
      case 'prayer':
        return '/prayer';
      case 'bible':
        return '/bible';
      case 'notes':
      case 'universal rule':
      case 'rule':
        return '/notes';
      case 'devotional':
        return '/more/devotionals';
      default:
        return '/notes';
    }
  }

  /// Icon emoji or string representation
  String get activityEmoji {
    switch (targetPage.toLowerCase()) {
      case 'prayer':
        return '🙏';
      case 'bible':
        return '📖';
      case 'notes':
        return '📝';
      case 'universal rule':
      case 'rule':
        return '📜';
      case 'devotional':
        return '✨';
      default:
        return '⏰';
    }
  }

  /// A reminder is active if it is enabled, not completed and not snoozed
  bool get isActive => isEnabled && !isCompleted && !isSnoozed;
}

class ReminderHistory {
  final int id;
  final int reminderId;
  final String action; // 'completed', 'snoozed', 'dismissed'
  final DateTime timestamp;

  const ReminderHistory({
    required this.id,
    required this.reminderId,
    required this.action,
    required this.timestamp,
  });

  factory ReminderHistory.fromJson(Map<String, dynamic> j) => ReminderHistory(
        id: j['id'] ?? 0,
        reminderId: j['reminder_id'] ?? 0,
        action: j['action'] ?? '',
        timestamp: DateTime.parse(j['timestamp'] ?? DateTime.now().toIso8601String()),
      );
}
