import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../repositories/notes_repository.dart';

final notesRepositoryProvider = Provider((_) => NotesRepository());

// ── Folders ──────────────────────────────────────────────────────
final noteFoldersProvider = FutureProvider<List<NoteFolder>>((ref) {
  return ref.read(notesRepositoryProvider).getFolders();
});

// ── Topics ───────────────────────────────────────────────────────
final notesTopicsProvider = FutureProvider<List<NoteTopic>>((ref) {
  return ref.read(notesRepositoryProvider).getTopics();
});

// ── Notes List ───────────────────────────────────────────────────
final notesProvider = StateNotifierProvider<NotesNotifier, AsyncValue<List<Note>>>((ref) {
  return NotesNotifier(ref.read(notesRepositoryProvider));
});

class NotesNotifier extends StateNotifier<AsyncValue<List<Note>>> {
  final NotesRepository _repo;
  int? _folderId;
  int? _topicId;
  bool _archived = false;
  String _search = '';

  NotesNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({int? folderId, int? topicId, bool? archived, String? search}) async {
    if (folderId != null) _folderId = folderId;
    if (topicId != null) _topicId = topicId;
    if (archived != null) _archived = archived;
    if (search != null) _search = search;
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getNotes(
        folderId: _folderId,
        topicId: _topicId,
        archived: _archived,
        search: _search.isNotEmpty ? _search : null,
      );
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => load();

  Future<void> setFolder(int? folderId) {
    _folderId = folderId;
    return load();
  }

  Future<void> setTopic(int? topicId) {
    _topicId = topicId;
    return load();
  }

  void setSearch(String search) => load(search: search);

  Future<void> create(Map<String, dynamic> data) async {
    await _repo.createNote(data);
    await refresh();
  }

  Future<void> update(int id, Map<String, dynamic> data) async {
    await _repo.updateNote(id, data);
    await refresh();
  }

  Future<void> delete(int id) async {
    await _repo.deleteNote(id);
    await refresh();
  }

  Future<void> togglePin(int id) async {
    await _repo.togglePin(id);
    await refresh();
  }

  Future<void> toggleFavorite(int id) async {
    await _repo.toggleFavorite(id);
    await refresh();
  }

  Future<void> archiveNote(int id) async {
    await _repo.archive(id);
    await refresh();
  }

  Future<void> restoreNote(int id) async {
    await _repo.restore(id);
    await refresh();
  }
}