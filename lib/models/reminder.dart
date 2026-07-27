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
  final String date;
  final String? time;
  final String repeat;
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
        'title': title,
        if (description != null) 'description': description,
        'date': date,
        if (time != null) 'time': time,
        'repeat': repeat,
        if (repeatUntil != null) 'repeat_until': repeatUntil,
        if (category != null) 'category': category,
      };

  Reminder copyWith({bool? isCompleted, bool? isSnoozed}) => Reminder(
        id: id,
        title: title,
        description: description,
        isCompleted: isCompleted ?? this.isCompleted,
        isSnoozed: isSnoozed ?? this.isSnoozed,
        date: date,
        time: time,
        repeat: repeat,
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

  /// A reminder is active if it is not completed and not snoozed
  bool get isActive => !isCompleted && !isSnoozed;
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
