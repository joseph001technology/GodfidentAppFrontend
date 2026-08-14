/// Matches `rules` app RuleCategorySerializer: id, name, color, icon,
/// order, rule_count, created_at, updated_at.
class RuleCategory {
  final int id;
  final String name;
  final String color;
  final String? icon;
  final int order;
  final int ruleCount;
  final String? createdAt;
  final String? updatedAt;

  const RuleCategory({
    required this.id,
    required this.name,
    this.color = '#6C5CE7',
    this.icon,
    this.order = 0,
    this.ruleCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory RuleCategory.fromJson(Map<String, dynamic> j) => RuleCategory(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        color: j['color'] ?? '#6C5CE7',
        icon: j['icon'],
        order: j['order'] ?? 0,
        ruleCount: j['rule_count'] ?? 0,
        createdAt: j['created_at'],
        updatedAt: j['updated_at'],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'color': color,
        if (icon != null) 'icon': icon,
        'order': order,
      };
}

/// Matches `rules` app RuleSerializer: id, title, description, category,
/// category_name, color, is_pinned, is_favorite, is_archived, order,
/// is_daily, is_completed_today, current_streak, created_at, updated_at.
///
/// Dropped vs. the old model: `category_color` (backend never sends it —
/// only `category_name`).
///
/// Renamed: `isCompleted` -> `isCompletedToday`, reading `is_completed_today`
/// (or `completed_today`, the extra key the `/rules/today/` action injects).
/// This field is read-only on the backend — completion is tracked via
/// separate daily RuleCompletion records, not a plain writable boolean.
class Rule {
  final int id;
  final String title;
  final String? description;
  final String color;
  final bool isCompletedToday;
  final int currentStreak;
  final bool isPinned;
  final bool isFavorite;
  final bool isArchived;
  final bool isDaily;
  final int order;
  final int? category;
  final String? categoryName;
  final String createdAt;
  final String? updatedAt;

  const Rule({
    required this.id,
    required this.title,
    this.description,
    this.color = '#6C5CE7',
    this.isCompletedToday = false,
    this.currentStreak = 0,
    this.isPinned = false,
    this.isFavorite = false,
    this.isArchived = false,
    this.isDaily = true,
    this.order = 0,
    this.category,
    this.categoryName,
    required this.createdAt,
    this.updatedAt,
  });

  factory Rule.fromJson(Map<String, dynamic> j) => Rule(
        id: j['id'] ?? 0,
        title: j['title'] ?? '',
        description: j['description'],
        color: j['color'] ?? '#6C5CE7',
        isCompletedToday: j['is_completed_today'] ?? j['completed_today'] ?? false,
        currentStreak: j['current_streak'] ?? 0,
        isPinned: j['is_pinned'] ?? false,
        isFavorite: j['is_favorite'] ?? false,
        isArchived: j['is_archived'] ?? false,
        isDaily: j['is_daily'] ?? true,
        order: j['order'] ?? 0,
        category: j['category'],
        categoryName: j['category_name'],
        createdAt: j['created_at'] ?? '',
        updatedAt: j['updated_at'],
      );

  /// Payload for POST /api/rules/ or PATCH /api/rules/{id}/.
  /// `is_completed_today` / `current_streak` are read-only on the backend
  /// (declared as ReadOnlyField) and deliberately excluded here — sending
  /// them would just be ignored, but excluding them avoids the confusion.
  Map<String, dynamic> toJson() => {
        'title': title,
        if (description != null) 'description': description,
        'color': color,
        'is_pinned': isPinned,
        'is_favorite': isFavorite,
        'is_daily': isDaily,
        if (category != null) 'category': category,
      };

  Rule copyWith({
    bool? isCompletedToday,
    bool? isPinned,
    bool? isFavorite,
    bool? isArchived,
  }) =>
      Rule(
        id: id,
        title: title,
        description: description,
        color: color,
        isCompletedToday: isCompletedToday ?? this.isCompletedToday,
        currentStreak: currentStreak,
        isPinned: isPinned ?? this.isPinned,
        isFavorite: isFavorite ?? this.isFavorite,
        isArchived: isArchived ?? this.isArchived,
        isDaily: isDaily,
        order: order,
        category: category,
        categoryName: categoryName,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}