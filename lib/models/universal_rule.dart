// ══════════════════════════════════════════════════════════════════════════
// UNIVERSAL RULE MODEL
// Used by LocalUniversalRulesRepository for offline/local rule management
// ══════════════════════════════════════════════════════════════════════════

enum RuleCategory {
  faith,
  mindset,
  health,
  work,
  relationships,
  custom;

  String get displayName {
    switch (this) {
      case RuleCategory.faith:
        return 'Faith';
      case RuleCategory.mindset:
        return 'Mindset';
      case RuleCategory.health:
        return 'Health';
      case RuleCategory.work:
        return 'Work';
      case RuleCategory.relationships:
        return 'Relationships';
      case RuleCategory.custom:
        return 'Custom';
    }
  }
}

class UniversalRule {
  final String id;
  final String title;
  final String description;
  final RuleCategory category;
  final String colorTag;
  final bool isPinned;
  final bool isCompleted;
  final bool isArchived;
  final bool repeatDaily;
  final DateTime? lastCompletedAt;
  final DateTime createdAt;

  const UniversalRule({
    required this.id,
    required this.title,
    this.description = '',
    this.category = RuleCategory.custom,
    this.colorTag = '#10B981',
    this.isPinned = false,
    this.isCompleted = false,
    this.isArchived = false,
    this.repeatDaily = false,
    this.lastCompletedAt,
    required this.createdAt,
  });

  factory UniversalRule.create({
    required String id,
    required String title,
    String description = '',
    RuleCategory category = RuleCategory.custom,
    String colorTag = '#10B981',
    bool isPinned = false,
  }) {
    return UniversalRule(
      id: id,
      title: title,
      description: description,
      category: category,
      colorTag: colorTag,
      isPinned: isPinned,
      createdAt: DateTime.now(),
    );
  }

  UniversalRule copyWith({
    String? id,
    String? title,
    String? description,
    RuleCategory? category,
    String? colorTag,
    bool? isPinned,
    bool? isCompleted,
    bool? isArchived,
    bool? repeatDaily,
    DateTime? lastCompletedAt,
    DateTime? createdAt,
  }) {
    return UniversalRule(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      colorTag: colorTag ?? this.colorTag,
      isPinned: isPinned ?? this.isPinned,
      isCompleted: isCompleted ?? this.isCompleted,
      isArchived: isArchived ?? this.isArchived,
      repeatDaily: repeatDaily ?? this.repeatDaily,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category.name,
        'color_tag': colorTag,
        'is_pinned': isPinned,
        'is_completed': isCompleted,
        'is_archived': isArchived,
        'repeat_daily': repeatDaily,
        'last_completed_at': lastCompletedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory UniversalRule.fromJson(Map<String, dynamic> j) => UniversalRule(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        category: RuleCategory.values.firstWhere(
          (c) => c.name == j['category'],
          orElse: () => RuleCategory.custom,
        ),
        colorTag: j['color_tag'] ?? '#10B981',
        isPinned: j['is_pinned'] ?? false,
        isCompleted: j['is_completed'] ?? false,
        isArchived: j['is_archived'] ?? false,
        repeatDaily: j['repeat_daily'] ?? false,
        lastCompletedAt: j['last_completed_at'] != null
            ? DateTime.tryParse(j['last_completed_at'])
            : null,
        createdAt: j['created_at'] != null
            ? DateTime.parse(j['created_at'])
            : DateTime.now(),
      );
}
