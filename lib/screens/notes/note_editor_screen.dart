import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
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
  bool _isPinned = false;
  bool _isFavorite = false;
  bool _loadedExisting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
    _loadExisting();
  }

  /// The notes list has no text in it, so an existing note is fetched whole.
  Future<void> _loadExisting() async {
    final id = int.tryParse(widget.noteId ?? '');
    if (id == null) return;
    try {
      final note = await ref.read(notesRepositoryProvider).getNote(id);
      if (!mounted) return;
      setState(() {
        _titleController.text = note.title;
        _bodyController.text = note.content;
        _isPinned = note.isPinned;
        _isFavorite = note.isFavorite;
        _loadedExisting = true;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load this note. Check your connection.')));
      }
    }
  }

  Future<void> _saveNote() async {
    if (widget.noteId != null && !_loadedExisting) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Still loading the note. Try again in a moment.')));
      return;
    }
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
    final editedId = int.tryParse(widget.noteId ?? '');
    if (editedId != null) ref.invalidate(noteDetailProvider(editedId));

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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontFamily: 'Lora', color: AppTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.bold, height: 1.25),
                  decoration: InputDecoration(
                    hintText: 'Title',
                    hintStyle: TextStyle(color: AppTheme.textMuted),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.navyOutline),
                  ),
                  child: Row(children: [
                    IconButton(
                      tooltip: _isPinned ? 'Unpin' : 'Pin',
                      icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: AppTheme.gold, size: 20),
                      onPressed: () => setState(() => _isPinned = !_isPinned),
                    ),
                    IconButton(
                      tooltip: _isFavorite ? 'Remove favorite' : 'Favorite',
                      icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: AppTheme.accentPink, size: 20),
                      onPressed: () => setState(() => _isFavorite = !_isFavorite),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _bodyController,
                      builder: (_, v, __) {
                        final words = v.text.trim().isEmpty ? 0 : v.text.trim().split(RegExp(r'\s+')).length;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text('$words word${words == 1 ? '' : 's'}',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted)),
                        );
                      },
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bodyController,
                  style: TextStyle(fontFamily: 'Lora', color: AppTheme.textPrimary, fontSize: 17, height: 1.75),
                  decoration: InputDecoration(
                    hintText: 'Write your thoughts, prayers, insights, a verse that spoke to you...',
                    hintStyle: TextStyle(color: AppTheme.textMuted),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 12,
                  maxLines: null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
