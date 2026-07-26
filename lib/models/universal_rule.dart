import 'package:intl/intl.dart';

// ══════════════════════════════════════════════════════════════════════════
// UNIVERSAL RULE MODEL
// ══════════════════════════════════════════════════════════════════════════

enum RuleCategory {
  prayer,
  reading,
  discipline,
  lifestyle,
  devotion,
  custom,
}

class UniversalRule {
  final String id;
  final String title;
  final String description;
  final RuleCategory category;
  final String colorTag; // Hex color for visual distinction
  final bool isPinned;
  final bool isArchived;
  final bool isCompleted; // Daily completion status
  final bool repeatDaily;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastCompletedAt;

  UniversalRule({
    required this.id,
    required this.title,
    this.description = '',
    this.category = RuleCategory.custom,
    this.colorTag = '#10B981', // Emerald by default
    this.isPinned = false,
    this.isArchived = false,
    this.isCompleted = false,
    this.repeatDaily = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastCompletedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory UniversalRule.fromJson(Map<String, dynamic> json) {
    return UniversalRule(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: _parseCategory(json['category'] ?? 'custom'),
      colorTag: json['color_tag'] ?? '#10B981',
      isPinned: json['is_pinned'] ?? false,
      isArchived: json['is_archived'] ?? false,
      isCompleted: json['is_completed'] ?? false,
      repeatDaily: json['repeat_daily'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      lastCompletedAt: json['last_completed_at'] != null
          ? DateTime.parse(json['last_completed_at'])
          : null,
    );
  }

  static RuleCategory _parseCategory(String? category) {
    switch (category?.toLowerCase()) {
      case 'prayer':
        return RuleCategory.prayer;
      case 'reading':
        return RuleCategory.reading;
      case 'discipline':
        return RuleCategory.discipline;
      case 'lifestyle':
        return RuleCategory.lifestyle;
      case 'devotion':
        return RuleCategory.devotion;
      default:
        return RuleCategory.custom;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category.toString().split('.').last,
        'color_tag': colorTag,
        'is_pinned': isPinned,
        'is_archived': isArchived,
        'is_completed': isCompleted,
        'repeat_daily': repeatDaily,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'last_completed_at': lastCompletedAt?.toIso8601String(),
      };

  String get categoryLabel {
    switch (category) {
      case RuleCategory.prayer:
        return 'Prayer';
      case RuleCategory.reading:
        return 'Reading';
      case RuleCategory.discipline:
        return 'Discipline';
      case RuleCategory.lifestyle:
        return 'Lifestyle';
      case RuleCategory.devotion:
        return 'Devotion';
      case RuleCategory.custom:
        return 'Custom';
    }
  }

  String get categoryEmoji {
    switch (category) {
      case RuleCategory.prayer:
        return '🙏';
      case RuleCategory.reading:
        return '📖';
      case RuleCategory.discipline:
        return '💪';
      case RuleCategory.lifestyle:
        return '✨';
      case RuleCategory.devotion:
        return '⛪';
      case RuleCategory.custom:
        return '📌';
    }
  }

  String get formattedDate {
    return DateFormat('MMM dd, yyyy').format(createdAt);
  }

  bool get isCompletedToday {
    if (lastCompletedAt == null) return false;
    final today = DateTime.now();
    return lastCompletedAt!.year == today.year &&
        lastCompletedAt!.month == today.month &&
        lastCompletedAt!.day == today.day;
  }

  UniversalRule copyWith({
    String? id,
    String? title,
    String? description,
    RuleCategory? category,
    String? colorTag,
    bool? isPinned,
    bool? isArchived,
    bool? isCompleted,
    bool? repeatDaily,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastCompletedAt,
  }) =>
      UniversalRule(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        colorTag: colorTag ?? this.colorTag,
        isPinned: isPinned ?? this.isPinned,
        isArchived: isArchived ?? this.isArchived,
        isCompleted: isCompleted ?? this.isCompleted,
        repeatDaily: repeatDaily ?? this.repeatDaily,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      );
}
