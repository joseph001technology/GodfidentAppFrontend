/// Matches devotionals... no — matches `notes` app: TopicSerializer fields
/// (id, name, color, created_at). Used both for the standalone
/// GET /api/notes/topics/ list and embedded as `topics_list` on each Note.
class NoteTopic {
  final int id;
  final String name;
  final String? color;

  const NoteTopic({required this.id, required this.name, this.color});

  factory NoteTopic.fromJson(Map<String, dynamic> j) => NoteTopic(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        color: j['color'],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (color != null) 'color': color,
      };
}

/// Matches `notes` app FolderSerializer: id, name, color, icon, parent,
/// order, note_count, created_at, updated_at. `parent` is the parent
/// folder's integer id (or null) — the old model had a separate,
/// nonexistent `parent_id` string field; backend never sends that.
class NoteFolder {
  final int id;
  final String name;
  final String color;
  final String? icon;
  final int? parent;
  final int order;
  final int noteCount;

  const NoteFolder({
    required this.id,
    required this.name,
    this.color = '#6C5CE7',
    this.icon,
    this.parent,
    this.order = 0,
    this.noteCount = 0,
  });

  factory NoteFolder.fromJson(Map<String, dynamic> j) => NoteFolder(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        color: j['color'] ?? '#6C5CE7',
        icon: j['icon'],
        parent: j['parent'],
        order: j['order'] ?? 0,
        noteCount: j['note_count'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'color': color,
        if (icon != null) 'icon': icon,
        if (parent != null) 'parent': parent,
        'order': order,
      };
}

/// Matches `notes` app NoteListSerializer / NoteDetailSerializer.
///
/// Dropped vs. the old model: `content_type`, `color` — neither field
/// exists on the backend Note model at all.
///
/// Fixed: `topics_list` (not `topic_names`) is what the backend actually
/// sends, and it's a list of objects `{id, name, color, created_at}`, not
/// a list of plain strings.
class Note {
  final int id;
  final String title;
  final String content;
  final bool isPinned;
  final bool isFavorite;
  final bool isArchived;
  final int? folder;
  final String? folderName;
  final List<int> topicIds; // only populated on detail (retrieve) responses
  final List<NoteTopic> topicsList; // populated on both list + detail
  final List<Map<String, dynamic>> bibleReferences;
  final int version;
  final String createdAt;
  final String updatedAt;
  final String? archivedAt;

  const Note({
    required this.id,
    required this.title,
    this.content = '',
    this.isPinned = false,
    this.isFavorite = false,
    this.isArchived = false,
    this.folder,
    this.folderName,
    this.topicIds = const [],
    this.topicsList = const [],
    this.bibleReferences = const [],
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] ?? 0,
        title: j['title'] ?? '',
        content: j['content'] ?? '',
        isPinned: j['is_pinned'] ?? false,
        isFavorite: j['is_favorite'] ?? false,
        isArchived: j['is_archived'] ?? false,
        folder: j['folder'],
        folderName: j['folder_name'],
        topicIds: (j['topics'] as List? ?? [])
            .map((e) => e is int ? e : int.tryParse('$e') ?? 0)
            .toList(),
        topicsList: (j['topics_list'] as List? ?? [])
            .map((t) => NoteTopic.fromJson(Map<String, dynamic>.from(t as Map)))
            .toList(),
        bibleReferences: (j['bible_references'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        version: j['version'] ?? 1,
        createdAt: j['created_at'] ?? '',
        updatedAt: j['updated_at'] ?? '',
        archivedAt: j['archived_at'],
      );

  /// Payload for POST /api/notes/ or PATCH /api/notes/{id}/.
  /// The M2M write field is `topic_ids` (NoteDetailSerializer.topic_ids),
  /// separate from the read-only `topics`/`topics_list` fields.
  Map<String, dynamic> toJson({List<int>? topicIds}) => {
        'title': title,
        'content': content,
        'is_pinned': isPinned,
        'is_favorite': isFavorite,
        if (folder != null) 'folder': folder,
        if (topicIds != null) 'topic_ids': topicIds,
      };

  Note copyWith({
    String? title,
    String? content,
    bool? isPinned,
    bool? isFavorite,
    bool? isArchived,
    int? folder,
  }) =>
      Note(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        isPinned: isPinned ?? this.isPinned,
        isFavorite: isFavorite ?? this.isFavorite,
        isArchived: isArchived ?? this.isArchived,
        folder: folder ?? this.folder,
        folderName: folderName,
        topicIds: topicIds,
        topicsList: topicsList,
        bibleReferences: bibleReferences,
        version: version,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
      );

  /// First topic's name, for compact single-tag card display.
  String get topicName => topicsList.isNotEmpty ? topicsList.first.name : '';
  List<String> get topicNames => topicsList.map((t) => t.name).toList();
}