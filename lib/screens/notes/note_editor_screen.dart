import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/note.dart';
import '../../providers/notes_provider.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;
  final String? topicId;

  const NoteEditorScreen({
    super.key,
    this.noteId,
    this.topicId,
  });

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  int? _selectedTopicId;
  bool _isPinned = false;
  bool _isFavorite = false;
  bool _loadedExisting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
    _selectedTopicId = widget.topicId != null ? int.tryParse(widget.topicId!) : null;
  }

  /// The old version of this screen never actually loaded the existing
  /// note's data when editing — the fields just opened blank. This fills
  /// them in from the cached notesProvider list once it's available.
  void _prefillIfEditing(List<Note> notes) {
    if (_loadedExisting || widget.noteId == null) return;
    final id = int.tryParse(widget.noteId!);
    if (id == null) return;
    final match = notes.where((n) => n.id == id);
    if (match.isEmpty) return;
    final note = match.first;
    _titleController.text = note.title;
    _bodyController.text = note.content;
    _isPinned = note.isPinned;
    _isFavorite = note.isFavorite;
    _selectedTopicId = note.topicIds.isNotEmpty ? note.topicIds.first : _selectedTopicId;
    _loadedExisting = true;
  }

  Future<void> _saveNote() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and body are required')),
      );
      return;
    }

    final notesRepo = ref.read(notesRepositoryProvider);

    // 'topic_ids' is the backend's write field name for the topics M2M
    // (see NoteDetailSerializer) — 'topics' is read-only there.
    final data = <String, dynamic>{
      'title': _titleController.text,
      'content': _bodyController.text,
      'topic_ids': _selectedTopicId != null ? [_selectedTopicId!] : <int>[],
      'is_pinned': _isPinned,
      'is_favorite': _isFavorite,
    };

    if (widget.noteId != null) {
      final id = int.tryParse(widget.noteId!) ?? 0;
      await notesRepo.updateNote(id, data);
    } else {
      await notesRepo.createNote(data);
    }

    ref.invalidate(notesProvider);

    if (mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.noteId != null ? 'Note updated' : 'Note created')),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(notesTopicsProvider);
    final notesAsync = ref.watch(notesProvider);
    notesAsync.whenData(_prefillIfEditing);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: Text(widget.noteId != null ? 'Edit Note' : 'New Note'),
        backgroundColor: AppTheme.navySurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _saveNote,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Note title',
                hintStyle: TextStyle(color: AppTheme.warmGray.withValues(alpha: 0.5)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),
            topicsAsync.when(
              data: (topics) => _buildTopicSelector(topics),
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => Text('Error: $err'),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.navyVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warmGray.withValues(alpha: 0.2)),
              ),
              child: TextField(
                controller: _bodyController,
                style: const TextStyle(color: Colors.white, height: 1.6),
                decoration: InputDecoration(
                  hintText: 'Write your thoughts, prayers, insights...',
                  hintStyle: TextStyle(color: AppTheme.warmGray.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 10,
                minLines: 5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pin Note', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                Switch(
                  value: _isPinned,
                  onChanged: (value) => setState(() => _isPinned = value),
                  activeThumbColor: AppTheme.emerald,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Favorite', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                Switch(
                  value: _isFavorite,
                  onChanged: (value) => setState(() => _isFavorite = value),
                  activeThumbColor: AppTheme.accentPink,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicSelector(List<NoteTopic> topics) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.navyVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
      ),
      child: DropdownButton<int?>(
        value: _selectedTopicId,
        isExpanded: true,
        underline: const SizedBox(),
        style: const TextStyle(color: Colors.white),
        dropdownColor: AppTheme.navyVariant,
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('Select a topic', style: TextStyle(color: AppTheme.warmGray)),
            ),
          ),
          ...topics.map((topic) {
            return DropdownMenuItem<int?>(
              value: topic.id,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(topic.name),
              ),
            );
          }),
        ],
        onChanged: (value) => setState(() => _selectedTopicId = value),
      ),
    );
  }
}