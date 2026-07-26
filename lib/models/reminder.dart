import 'package:intl/intl.dart';

// ══════════════════════════════════════════════════════════════════════════
// REMINDER MODEL
// ══════════════════════════════════════════════════════════════════════════

enum ReminderFrequency {
  once,
  daily,
  weekly,
  monthly,
  custom,
}

enum ReminderCategory {
  prayer,
  bibleReading,
  devotion,
  church,
  fasting,
  sleep,
  water,
  meditation,
  custom, bible,
}

class Reminder {
  final String id;
  final String title;
  final String description;
  final ReminderCategory category;
  final DateTime scheduledTime;
  final ReminderFrequency frequency;
  final DateTime? repeatUntil;
  final List<int> daysOfWeek; // For weekly reminders: [0=Monday, ..., 6=Sunday]
  final bool isEnabled;
  final bool repeatUntilCompleted;
  final int snoozeDurationMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSentAt;
  final int completionCount;

  Reminder({
    required this.id,
    required this.title,
    this.description = '',
    this.category = ReminderCategory.custom,
    required this.scheduledTime,
    this.frequency = ReminderFrequency.daily,
    this.repeatUntil,
    this.daysOfWeek = const [],
    this.isEnabled = true,
    this.repeatUntilCompleted = false,
    this.snoozeDurationMinutes = 5,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastSentAt,
    this.completionCount = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Duration get snoozeDuration => Duration(minutes: snoozeDurationMinutes);

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: _parseCategory(json['category']),
      scheduledTime: json['scheduled_time'] != null
          ? DateTime.parse(json['scheduled_time'])
          : DateTime.now(),
      frequency: _parseFrequency(json['frequency']),
      repeatUntil: json['repeat_until'] != null
          ? DateTime.parse(json['repeat_until'])
          : null,
      daysOfWeek: List<int>.from(json['days_of_week'] ?? []),
      isEnabled: json['is_enabled'] ?? true,
      repeatUntilCompleted: json['repeat_until_completed'] ?? false,
      snoozeDurationMinutes: json['snooze_duration_minutes'] ?? 5,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      lastSentAt: json['last_sent_at'] != null
          ? DateTime.parse(json['last_sent_at'])
          : null,
      completionCount: json['completion_count'] ?? 0,
    );
  }

  static ReminderCategory _parseCategory(String? category) {
    switch (category?.toLowerCase()) {
      case 'prayer':
        return ReminderCategory.prayer;
      case 'bible_reading':
        return ReminderCategory.bibleReading;
      case 'devotion':
        return ReminderCategory.devotion;
      case 'church':
        return ReminderCategory.church;
      case 'fasting':
        return ReminderCategory.fasting;
      case 'sleep':
        return ReminderCategory.sleep;
      case 'water':
        return ReminderCategory.water;
      case 'meditation':
        return ReminderCategory.meditation;
      default:
        return ReminderCategory.custom;
    }
  }

  static ReminderFrequency _parseFrequency(String? frequency) {
    switch (frequency?.toLowerCase()) {
      case 'once':
        return ReminderFrequency.once;
      case 'daily':
        return ReminderFrequency.daily;
      case 'weekly':
        return ReminderFrequency.weekly;
      case 'monthly':
        return ReminderFrequency.monthly;
      case 'custom':
        return ReminderFrequency.custom;
      default:
        return ReminderFrequency.daily;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category.toString().split('.').last,
        'scheduled_time': scheduledTime.toIso8601String(),
        'frequency': frequency.toString().split('.').last,
        'repeat_until': repeatUntil?.toIso8601String(),
        'days_of_week': daysOfWeek,
        'is_enabled': isEnabled,
        'repeat_until_completed': repeatUntilCompleted,
        'snooze_duration_minutes': snoozeDurationMinutes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'last_sent_at': lastSentAt?.toIso8601String(),
        'completion_count': completionCount,
      };

  String get categoryLabel {
    switch (category) {
      case ReminderCategory.prayer:
        return 'Prayer';
      case ReminderCategory.bibleReading:
        return 'Bible Reading';
      case ReminderCategory.bible:
        return 'Bible';
      case ReminderCategory.devotion:
        return 'Devotion';
      case ReminderCategory.church:
        return 'Church';
      case ReminderCategory.fasting:
        return 'Fasting';
      case ReminderCategory.sleep:
        return 'Sleep';
      case ReminderCategory.water:
        return 'Water';
      case ReminderCategory.meditation:
        return 'Meditation';
      case ReminderCategory.custom:
        return 'Custom';
    }
  }

  String get categoryEmoji {
    switch (category) {
      case ReminderCategory.prayer:
        return '🙏';
      case ReminderCategory.bibleReading:
        return '📖';
      case ReminderCategory.bible:
        return '📖';
      case ReminderCategory.devotion:
        return '⛪';
      case ReminderCategory.church:
        return '⛪';
      case ReminderCategory.fasting:
        return '🤍';
      case ReminderCategory.sleep:
        return '😴';
      case ReminderCategory.water:
        return '💧';
      case ReminderCategory.meditation:
        return '🧘';
      case ReminderCategory.custom:
        return '⏰';
    }
  }

  String get formattedTime {
    return DateFormat('hh:mm a').format(scheduledTime);
  }

  String get frequencyLabel {
    switch (frequency) {
      case ReminderFrequency.once:
        return 'One time';
      case ReminderFrequency.daily:
        return 'Every day';
      case ReminderFrequency.weekly:
        return 'Every week';
      case ReminderFrequency.monthly:
        return 'Every month';
      case ReminderFrequency.custom:
        return 'Custom';
    }
  }

  bool get isActive {
    return isEnabled && (repeatUntil == null || repeatUntil!.isAfter(DateTime.now()));
  }

  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    ReminderCategory? category,
    DateTime? scheduledTime,
    ReminderFrequency? frequency,
    DateTime? repeatUntil,
    List<int>? daysOfWeek,
    bool? isEnabled,
    bool? repeatUntilCompleted,
    int? snoozeDurationMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSentAt,
    int? completionCount,
  }) =>
      Reminder(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        scheduledTime: scheduledTime ?? this.scheduledTime,
        frequency: frequency ?? this.frequency,
        repeatUntil: repeatUntil ?? this.repeatUntil,
        daysOfWeek: daysOfWeek ?? this.daysOfWeek,
        isEnabled: isEnabled ?? this.isEnabled,
        repeatUntilCompleted: repeatUntilCompleted ?? this.repeatUntilCompleted,
        snoozeDurationMinutes: snoozeDurationMinutes ?? this.snoozeDurationMinutes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastSentAt: lastSentAt ?? this.lastSentAt,
        completionCount: completionCount ?? this.completionCount,
      );
}
