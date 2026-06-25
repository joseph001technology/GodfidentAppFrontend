class DevotionalCategory {
  final int id;
  final String name;
  final String description;
  final String icon;

  const DevotionalCategory({
    required this.id,
    required this.name,
    this.description = '',
    this.icon = '',
  });

  factory DevotionalCategory.fromJson(Map<String, dynamic> j) => DevotionalCategory(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        description: j['description'] ?? '',
        icon: j['icon'] ?? '',
      );
}

class Devotional {
  final int id;
  final String title;
  final String scriptureReference;
  final String scriptureText;
  final String reflection;
  final String prayer;
  final String application;
  final String keyTakeaway;
  final String author;
  final int? category;
  final String? categoryName;
  final String? publishDate;
  final bool isSaved;
  final bool isRead;
  final String createdAt;

  const Devotional({
    required this.id,
    required this.title,
    required this.scriptureReference,
    required this.scriptureText,
    required this.reflection,
    required this.prayer,
    this.application = '',
    this.keyTakeaway = '',
    this.author = 'Godfident',
    this.category,
    this.categoryName,
    this.publishDate,
    this.isSaved = false,
    this.isRead = false,
    required this.createdAt,
  });

  factory Devotional.fromJson(Map<String, dynamic> j) => Devotional(
        id: j['id'] ?? 0,
        title: j['title'] ?? '',
        scriptureReference: j['scripture_reference'] ?? '',
        scriptureText: j['scripture_text'] ?? '',
        reflection: j['reflection'] ?? '',
        prayer: j['prayer'] ?? '',
        application: j['application'] ?? '',
        keyTakeaway: j['key_takeaway'] ?? '',
        author: j['author'] ?? 'Godfident',
        category: j['category'],
        categoryName: j['category_name'],
        publishDate: j['publish_date'],
        isSaved: j['is_saved'] ?? false,
        isRead: j['is_read'] ?? false,
        createdAt: j['created_at'] ?? '',
      );

  Devotional copyWith({bool? isSaved}) => Devotional(
        id: id,
        title: title,
        scriptureReference: scriptureReference,
        scriptureText: scriptureText,
        reflection: reflection,
        prayer: prayer,
        application: application,
        keyTakeaway: keyTakeaway,
        author: author,
        category: category,
        categoryName: categoryName,
        publishDate: publishDate,
        isSaved: isSaved ?? this.isSaved,
        isRead: isRead,
        createdAt: createdAt,
      );
}
