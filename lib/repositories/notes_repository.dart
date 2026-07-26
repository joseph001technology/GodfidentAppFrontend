import '../models/note.dart';
import 'package:uuid/uuid.dart';

// ══════════════════════════════════════════════════════════════════════════
// NOTES REPOSITORY
// ══════════════════════════════════════════════════════════════════════════

abstract class NotesRepository {
  // Topics
  Future<List<NoteTopic>> getAllTopics();
  Future<NoteTopic> createTopic(String name, {String description});
  Future<void> updateTopic(NoteTopic topic);
  Future<void> deleteTopic(String topicId);

  // Notes
  Future<List<Note>> getNotesByTopic(String topicId);
  Future<List<Note>> getAllNotes();
  Future<Note?> getNote(String noteId);
  Future<Note> createNote(String title, String content, String topicId);
  Future<void> updateNote(Note note);
  Future<void> deleteNote(String noteId);

  // Search & Filter
  Future<List<Note>> searchNotes(String query);
  Future<List<Note>> getFavorites();
  Future<List<Note>> getArchivedNotes();
  Future<List<Note>> getPinnedNotes();

  // Operations
  Future<void> toggleFavorite(String noteId);
  Future<void> toggleArchive(String noteId);
  Future<void> togglePin(String noteId);
  Future<void> addBibleReference(String noteId, String reference);
  Future<void> removeBibleReference(String noteId, String reference);
}

// ══════════════════════════════════════════════════════════════════════════
// LOCAL NOTES REPOSITORY (Using Shared Preferences + Local Storage)
// ══════════════════════════════════════════════════════════════════════════

class LocalNotesRepository implements NotesRepository {
  // Mock data storage (will be replaced with local database)
  final Map<String, NoteTopic> _topics = {};
  final Map<String, Note> _notes = {};
  static const _uuid = Uuid();

  @override
  Future<List<NoteTopic>> getAllTopics() async {
    // TODO: Persist to local storage
    return _topics.values.toList();
  }

  @override
  Future<NoteTopic> createTopic(String name, {String description = ''}) async {
    final topic = NoteTopic(
      id: _uuid.v4(),
      name: name,
      description: description,
    );
    _topics[topic.id] = topic;
    // TODO: Save to local storage
    return topic;
  }

  @override
  Future<void> updateTopic(NoteTopic topic) async {
    _topics[topic.id] = topic;
    // TODO: Save to local storage
  }

  @override
  Future<void> deleteTopic(String topicId) async {
    _topics.remove(topicId);
    // Also remove notes in this topic
    _notes.removeWhere((key, note) => note.topicId == topicId);
    // TODO: Save to local storage
  }

  @override
  Future<List<Note>> getNotesByTopic(String topicId) async {
    return _notes.values.where((note) => note.topicId == topicId).toList();
  }

  @override
  Future<List<Note>> getAllNotes() async {
    return _notes.values.toList();
  }

  @override
  Future<Note?> getNote(String noteId) async {
    return _notes[noteId];
  }

  @override
  Future<Note> createNote(String title, String content, String topicId) async {
    final note = Note(
      id: _uuid.v4(),
      title: title,
      content: content,
      topicId: topicId,
    );
    _notes[note.id] = note;
    // Update topic note count
    if (_topics.containsKey(topicId)) {
      final topic = _topics[topicId]!;
      _topics[topicId] = topic.copyWith(noteCount: topic.noteCount + 1);
    }
    // TODO: Save to local storage
    return note;
  }

  @override
  Future<void> updateNote(Note note) async {
    _notes[note.id] = note;
    // TODO: Save to local storage
  }

  @override
  Future<void> deleteNote(String noteId) async {
    final note = _notes[noteId];
    _notes.remove(noteId);
    // Update topic note count
    if (note != null && _topics.containsKey(note.topicId)) {
      final topic = _topics[note.topicId]!;
      _topics[note.topicId] =
          topic.copyWith(noteCount: max(0, topic.noteCount - 1));
    }
    // TODO: Save to local storage
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    final lowerQuery = query.toLowerCase();
    return _notes.values
        .where((note) =>
            note.title.toLowerCase().contains(lowerQuery) ||
            note.content.toLowerCase().contains(lowerQuery))
        .toList();
  }

  @override
  Future<List<Note>> getFavorites() async {
    return _notes.values.where((note) => note.isFavorite).toList();
  }

  @override
  Future<List<Note>> getArchivedNotes() async {
    return _notes.values.where((note) => note.isArchived).toList();
  }

  @override
  Future<List<Note>> getPinnedNotes() async {
    return _notes.values.where((note) => note.isPinned).toList();
  }

  @override
  Future<void> toggleFavorite(String noteId) async {
    if (_notes.containsKey(noteId)) {
      final note = _notes[noteId]!;
      _notes[noteId] = note.copyWith(isFavorite: !note.isFavorite);
      // TODO: Save to local storage
    }
  }

  @override
  Future<void> toggleArchive(String noteId) async {
    if (_notes.containsKey(noteId)) {
      final note = _notes[noteId]!;
      _notes[noteId] = note.copyWith(isArchived: !note.isArchived);
      // TODO: Save to local storage
    }
  }

  @override
  Future<void> togglePin(String noteId) async {
    if (_notes.containsKey(noteId)) {
      final note = _notes[noteId]!;
      _notes[noteId] = note.copyWith(isPinned: !note.isPinned);
      // TODO: Save to local storage
    }
  }

  @override
  Future<void> addBibleReference(String noteId, String reference) async {
    if (_notes.containsKey(noteId)) {
      final note = _notes[noteId]!;
      if (!note.bibleReferences.contains(reference)) {
        final updatedRefs = [...note.bibleReferences, reference];
        _notes[noteId] = note.copyWith(bibleReferences: updatedRefs);
        // TODO: Save to local storage
      }
    }
  }

  @override
  Future<void> removeBibleReference(String noteId, String reference) async {
    if (_notes.containsKey(noteId)) {
      final note = _notes[noteId]!;
      final updatedRefs =
          note.bibleReferences.where((r) => r != reference).toList();
      _notes[noteId] = note.copyWith(bibleReferences: updatedRefs);
      // TODO: Save to local storage
    }
  }
}

// Helper function
int max(int a, int b) => a > b ? a : b;
