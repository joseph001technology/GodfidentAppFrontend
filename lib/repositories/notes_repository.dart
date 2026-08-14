import '../core/dio_client.dart';
import '../core/api_response.dart';
import '../models/note.dart';

class NotesRepository {
  final _dio = DioClient.instance;

  // ── Folders ────────────────────────────────────────────────────
  Future<List<NoteFolder>> getFolders() async {
    final res = await _dio.get('/api/notes/folders/');
    return readList(res.data).map((j) => NoteFolder.fromJson(readMap(j))).toList();
  }

  Future<NoteFolder> createFolder(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/notes/folders/', data: data);
    return NoteFolder.fromJson(readMap(res.data));
  }

  Future<NoteFolder> updateFolder(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/notes/folders/$id/', data: data);
    return NoteFolder.fromJson(readMap(res.data));
  }

  Future<void> deleteFolder(int id) async {
    await _dio.delete('/api/notes/folders/$id/');
  }

  // ── Topics ─────────────────────────────────────────────────────
  Future<List<NoteTopic>> getTopics() async {
    final res = await _dio.get('/api/notes/topics/');
    return readList(res.data).map((j) => NoteTopic.fromJson(readMap(j))).toList();
  }

  Future<NoteTopic> createTopic(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/notes/topics/', data: data);
    return NoteTopic.fromJson(readMap(res.data));
  }

  // ── Notes ──────────────────────────────────────────────────────
  // These four query param names are the ONLY ones NoteViewSet.get_queryset()
  // reads (folder_id, archived, favorite, topic_id) — the viewset has no
  // DjangoFilterBackend field mapping wired up, so anything else (e.g. the
  // old 'folder'/'is_archived' keys) is silently ignored by the backend.
  Future<List<Note>> getNotes({
    int? folderId,
    int? topicId,
    bool? archived,
    bool? favorite,
    String? search,
    String ordering = '-updated_at',
  }) async {
    final res = await _dio.get('/api/notes/', queryParameters: {
      if (folderId != null) 'folder_id': folderId,
      if (topicId != null) 'topic_id': topicId,
      if (archived != null) 'archived': archived,
      if (favorite != null) 'favorite': favorite,
      if (search != null) 'search': search,
      'ordering': ordering,
    });
    return readList(res.data).map((j) => Note.fromJson(readMap(j))).toList();
  }

  Future<Note> getNote(int id) async {
    final res = await _dio.get('/api/notes/$id/');
    return Note.fromJson(readDataMap(res.data));
  }

  Future<Note> createNote(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/notes/', data: data);
    return Note.fromJson(readDataMap(res.data));
  }

  Future<Note> updateNote(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/notes/$id/', data: data);
    return Note.fromJson(readDataMap(res.data));
  }

  Future<void> deleteNote(int id) async {
    await _dio.delete('/api/notes/$id/');
  }

  /// POST /notes/{id}/toggle_pin/ returns {'success', 'is_pinned'} only —
  /// never the full Note — so this returns just the new flag. Callers should
  /// refresh() the list provider afterwards to pick up the updated Note.
  Future<bool> togglePin(int id) async {
    final res = await _dio.post('/api/notes/$id/toggle_pin/');
    return readMap(res.data)['is_pinned'] == true;
  }

  Future<bool> toggleFavorite(int id) async {
    final res = await _dio.post('/api/notes/$id/toggle_favorite/');
    return readMap(res.data)['is_favorite'] == true;
  }

  Future<void> archive(int id) async {
    await _dio.post('/api/notes/$id/archive/');
  }

  Future<void> restore(int id) async {
    await _dio.post('/api/notes/$id/restore/');
  }
}