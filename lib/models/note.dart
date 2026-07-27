class NoteFolder {
  final int id;
  final String name;
  final String? parent;
  final int? parentId;
  final int noteCount;
  final List<NoteFolder> children;

  const NoteFolder({
    required this.id,
    required this.name,
    this.parent,
    this.parentId,
    this.noteCount = 0,
    this.children = const [],
  });

  factory NoteFolder.fromJson(Map<String, dynamic> j) => NoteFolder(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        parent: j['parent'],
        parentId: j['parent_id'],
        noteCount: j['note_count'] ?? 0,
        children: (j['children'] as List? ?? [])
            .map((c) => NoteFolder.fromJson(c))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (parentId != null) 'parent': parentId,
      };
}

class NoteTopic {
  final int id;
  final String name;
  final String? description;

  const NoteTopic({required this.id, required this.name, this.description});

  factory NoteTopic.fromJson(Map<String, dynamic> j) => NoteTopic(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        description: j['description'],
      );

  Map<String, dynamic> toJson() => {'name': name, if (description != null) 'description': description};
}

class Note {
  final int id;
  final String title;
  final String content;
  final String contentType; // 'text' or 'rich_text'
  final bool isPinned;
  final bool isFavorite;
  final bool isArchived;
  final List<int> topics;
  final List<String> topicNames;
  final int? folder;
  final String? folderName;
  final String createdAt;
  final String updatedAt;
  final String? color;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    this.contentType = 'text',
    this.isPinned = false,
    this.isFavorite = false,
    this.isArchived = false,
    this.topics = const [],
    this.topicNames = const [],
    this.folder,
    this.folderName,
    required this.createdAt,
    required this.updatedAt,
    this.color,
  });

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] ?? 0,
        title: j['title'] ?? '',
        content: j['content'] ?? '',
        contentType: j['content_type'] ?? 'text',
        isPinned: j['is_pinned'] ?? false,
        isFavorite: j['is_favorite'] ?? false,
        isArchived: j['is_archived'] ?? false,
        topics: (j['topics'] as List? ?? []).map((e) => e is int ? e : int.tryParse('$e') ?? 0).toList(),
        topicNames: (j['topic_names'] as List? ?? []).map((e) => '$e').toList(),
        folder: j['folder'],
        folderName: j['folder_name'],
        createdAt: j['created_at'] ?? '',
        updatedAt: j['updated_at'] ?? '',
        color: j['color'],
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'content_type': contentType,
        'is_pinned': isPinned,
        'is_favorite': isFavorite,
        if (folder != null) 'folder': folder,
        if (color != null) 'color': color,
        if (topics.isNotEmpty) 'topics': topics,
      };

  Note copyWith({
    String? title,
    String? content,
    bool? isPinned,
    bool? isFavorite,
    bool? isArchived,
    int? folder,
    String? color,
  }) =>
      Note(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        contentType: contentType,
        isPinned: isPinned ?? this.isPinned,
        isFavorite: isFavorite ?? this.isFavorite,
        isArchived: isArchived ?? this.isArchived,
        topics: topics,
        topicNames: topicNames,
        folder: folder ?? this.folder,
        folderName: folderName,
        createdAt: createdAt,
        updatedAt: updatedAt,
        color: color ?? this.color,
      );

  /// Returns the first topic name for display purposes, or empty string
  String get topicName => topicNames.isNotEmpty ? topicNames.first : '';
}
