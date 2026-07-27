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
  int? _selectedTopicId;
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
    _bibleRefController = TextEditingController();
    _selectedTopicId = widget.topicId != null ? int.tryParse(widget.topicId!) : null;
  }

  Future<void> _saveNote() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and body are required')),
      );
      return;
    }

    final notesRepo = ref.read(notesRepositoryProvider);

    final data = <String, dynamic>{
      'title': _titleController.text,
      'content': _bodyController.text,
      if (_selectedTopicId != null) 'topics': [_selectedTopicId!],
      'is_pinned': _isPinned,
    };

    if (widget.noteId != null) {
      final id = int.tryParse(widget.noteId!) ?? 0;
      await notesRepo.updateNote(id, data);
    } else {
      await notesRepo.createNote(data);
    }

    // Invalidate providers
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
                  prefixIcon: const Icon(Icons.book, color: AppTheme.emerald),
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
                  activeThumbColor: AppTheme.emerald,
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
              child: Text(
                'Select a topic',
                style: TextStyle(color: AppTheme.warmGray),
              ),
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
