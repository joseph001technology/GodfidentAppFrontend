import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/note.dart';
import '../../providers/remaining_providers.dart';

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
  late TextEditingController _bibleRefController;
  String? _selectedTopicId;
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
    _bibleRefController = TextEditingController();
    _selectedTopicId = widget.topicId;
  }

  Future<void> _saveNote() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and body are required')),
      );
      return;
    }

    if (_selectedTopicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a topic')),
      );
      return;
    }

    final notesRepo = ref.read(notesRepositoryProvider);
    final bibleRefs = _bibleRefController.text
        .split(',')
        .map((ref) => ref.trim())
        .where((ref) => ref.isNotEmpty)
        .toList();

    if (widget.noteId != null) {
      // Update existing note
      final note = Note(
        id: widget.noteId!,
        topicId: _selectedTopicId!,
        title: _titleController.text,
        content: _bodyController.text,
        bibleReferences: bibleRefs,
        isFavorite: false,
        isPinned: _isPinned,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await notesRepo.updateNote(note);
    } else {
      // Create new note
      await notesRepo.createNote(
        _titleController.text,
        _bodyController.text,
        _selectedTopicId!,
      );
    }

    // Invalidate providers
    ref.invalidate(notesProvider);
    ref.invalidate(notesByTopicProvider);
    ref.invalidate(favoritesNotesProvider);

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
    _bibleRefController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(notesTopicsProvider);

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
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: _saveNote,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
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
            // Title field
            TextField(
              controller: _titleController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'Note title',
                hintStyle: TextStyle(color: AppTheme.warmGray.withValues(alpha: 0.5)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),
            // Topic selector
            topicsAsync.when(
              data: (topics) => _buildTopicSelector(topics),
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => Text('Error: $err'),
            ),
            const SizedBox(height: 20),
            // Bible references field
            Container(
              decoration: BoxDecoration(
                color: AppTheme.navyVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
              ),
              child: TextField(
                controller: _bibleRefController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Bible references (e.g., John 3:16, Psalm 23:1)',
                  hintStyle: TextStyle(color: AppTheme.warmGray.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                  prefixIcon: Icon(Icons.book, color: AppTheme.emerald),
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 20),
            // Body
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
            // Pin toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pin Note',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                Switch(
                  value: _isPinned,
                  onChanged: (value) => setState(() => _isPinned = value),
                  activeColor: AppTheme.emerald,
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
      child: DropdownButton<String>(
        value: _selectedTopicId,
        isExpanded: true,
        underline: const SizedBox(),
        style: const TextStyle(color: Colors.white),
        dropdownColor: AppTheme.navyVariant,
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Select a topic',
                style: TextStyle(color: AppTheme.warmGray),
              ),
            ),
          ),
          ...topics.map((topic) {
            return DropdownMenuItem<String>(
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
