class RuleCategory {
  final int id;
  final String name;
  final String? color;
  final String? icon;

  const RuleCategory({required this.id, required this.name, this.color, this.icon});

  factory RuleCategory.fromJson(Map<String, dynamic> j) => RuleCategory(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        color: j['color'],
        icon: j['icon'],
      );

  Map<String, dynamic> toJson() => {'name': name, if (color != null) 'color': color, if (icon != null) 'icon': icon};
}

class Rule {
  final int id;
  final String title;
  final String? description;
  final bool isCompleted;
  final bool isPinned;
  final bool isFavorite;
  final bool isArchived;
  final int order;
  final int? category;
  final String? categoryName;
  final String? categoryColor;
  final String createdAt;

  const Rule({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.isPinned = false,
    this.isFavorite = false,
    this.isArchived = false,
    this.order = 0,
    this.category,
    this.categoryName,
    this.categoryColor,
    required this.createdAt,
  });

  factory Rule.fromJson(Map<String, dynamic> j) => Rule(
        id: j['id'] ?? 0,
        title: j['title'] ?? '',
        description: j['description'],
        isCompleted: j['is_completed'] ?? false,
        isPinned: j['is_pinned'] ?? false,
        isFavorite: j['is_favorite'] ?? false,
        isArchived: j['is_archived'] ?? false,
        order: j['order'] ?? 0,
        category: j['category'],
        categoryName: j['category_name'],
        categoryColor: j['category_color'],
        createdAt: j['created_at'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        if (description != null) 'description': description,
        'is_completed': isCompleted,
        'is_pinned': isPinned,
        'is_favorite': isFavorite,
        if (category != null) 'category': category,
        'order': order,
      };

  Rule copyWith({bool? isCompleted, bool? isPinned, bool? isFavorite, bool? isArchived}) =>
      Rule(
        id: id,
        title: title,
        description: description,
        isCompleted: isCompleted ?? this.isCompleted,
        isPinned: isPinned ?? this.isPinned,
        isFavorite: isFavorite ?? this.isFavorite,
        isArchived: isArchived ?? this.isArchived,
        order: order,
        category: category,
        categoryName: categoryName,
        categoryColor: categoryColor,
        createdAt: createdAt,
      );
}
