import '../core/dio_client.dart';
import '../core/api_response.dart';
import '../models/note.dart';

class NotesRepository {
  final _dio = DioClient.instance;

  // ── Folders ────────────────────────────────────────────────────
  Future<List<NoteFolder>> getFolders() async {
    final res = await _dio.get('/api/notes/folders/');
    return (readList(res.data) as List).map((j) => NoteFolder.fromJson(j)).toList();
  }

  Future<NoteFolder> createFolder(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/notes/folders/', data: data);
    return NoteFolder.fromJson(res.data);
  }

  Future<NoteFolder> updateFolder(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/notes/folders/$id/', data: data);
    return NoteFolder.fromJson(res.data);
  }

  Future<void> deleteFolder(int id) async {
    await _dio.delete('/api/notes/folders/$id/');
  }

  // ── Topics ─────────────────────────────────────────────────────
  Future<List<NoteTopic>> getTopics() async {
    final res = await _dio.get('/api/notes/topics/');
    return (readList(res.data) as List).map((j) => NoteTopic.fromJson(j)).toList();
  }

  Future<NoteTopic> createTopic(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/notes/topics/', data: data);
    return NoteTopic.fromJson(res.data);
  }

  // ── Notes ──────────────────────────────────────────────────────
  Future<List<Note>> getNotes({
    int? folderId,
    bool? archived,
    String? search,
    String ordering = '-updated_at',
  }) async {
    final res = await _dio.get('/api/notes/', queryParameters: {
      if (folderId != null) 'folder': folderId,
      if (archived != null) 'is_archived': archived,
      if (search != null) 'search': search,
      'ordering': ordering,
    });
    return (readList(res.data) as List).map((j) => Note.fromJson(j)).toList();
  }

  Future<Note> getNote(int id) async {
    final res = await _dio.get('/api/notes/$id/');
    return Note.fromJson(res.data['data'] ?? res.data);
  }

  Future<Note> createNote(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/notes/', data: data);
    return Note.fromJson(res.data);
  }

  Future<Note> updateNote(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/notes/$id/', data: data);
    return Note.fromJson(res.data);
  }

  Future<void> deleteNote(int id) async {
    await _dio.delete('/api/notes/$id/');
  }

  Future<Note> togglePin(int id) async {
    final res = await _dio.post('/api/notes/$id/toggle_pin/');
    return Note.fromJson(res.data['data'] ?? res.data);
  }

  Future<Note> toggleFavorite(int id) async {
    final res = await _dio.post('/api/notes/$id/toggle_favorite/');
    return Note.fromJson(res.data['data'] ?? res.data);
  }

  Future<void> archive(int id) async {
    await _dio.post('/api/notes/$id/archive/');
  }

  Future<void> restore(int id) async {
    await _dio.post('/api/notes/$id/restore/');
  }
}
