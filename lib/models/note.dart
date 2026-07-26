import 'package:intl/intl.dart';

// ══════════════════════════════════════════════════════════════════════════
// NOTE TOPIC MODEL
// ══════════════════════════════════════════════════════════════════════════

class NoteTopic {
  final String id;
  final String name;
  final String description;
  final int noteCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteTopic({
    required this.id,
    required this.name,
    this.description = '',
    this.noteCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory NoteTopic.fromJson(Map<String, dynamic> json) {
    return NoteTopic(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      noteCount: json['note_count'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'note_count': noteCount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  NoteTopic copyWith({
    String? id,
    String? name,
    String? description,
    int? noteCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      NoteTopic(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        noteCount: noteCount ?? this.noteCount,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ══════════════════════════════════════════════════════════════════════════
// NOTE MODEL
// ══════════════════════════════════════════════════════════════════════════

class Note {
  final String id;
  final String title;
  final String content;
  final String topicId;
  final List<String> bibleReferences; // e.g., ["John 3:16", "Romans 12:1"]
  final bool isFavorite;
  final bool isArchived;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastEditedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.topicId,
    this.bibleReferences = const [],
    this.isFavorite = false,
    this.isArchived = false,
    this.isPinned = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastEditedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      topicId: json['topic_id'] ?? '',
      bibleReferences: List<String>.from(json['bible_references'] ?? []),
      isFavorite: json['is_favorite'] ?? false,
      isArchived: json['is_archived'] ?? false,
      isPinned: json['is_pinned'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      lastEditedAt: json['last_edited_at'] != null
          ? DateTime.parse(json['last_edited_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'topic_id': topicId,
        'bible_references': bibleReferences,
        'is_favorite': isFavorite,
        'is_archived': isArchived,
        'is_pinned': isPinned,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'last_edited_at': lastEditedAt?.toIso8601String(),
      };

  String get formattedDate {
    return DateFormat('MMM dd, yyyy').format(updatedAt);
  }

  String get formattedTime {
    return DateFormat('HH:mm').format(updatedAt);
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? topicId,
    List<String>? bibleReferences,
    bool? isFavorite,
    bool? isArchived,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastEditedAt,
  }) =>
      Note(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
        topicId: topicId ?? this.topicId,
        bibleReferences: bibleReferences ?? this.bibleReferences,
        isFavorite: isFavorite ?? this.isFavorite,
        isArchived: isArchived ?? this.isArchived,
        isPinned: isPinned ?? this.isPinned,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastEditedAt: lastEditedAt ?? this.lastEditedAt,
      );
}
