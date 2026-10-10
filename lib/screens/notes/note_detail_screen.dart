import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/notes_provider.dart';
import '../../widgets/common/app_widgets.dart';

class NoteDetailScreen extends ConsumerWidget {
  final int noteId;
  const NoteDetailScreen({super.key, required this.noteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The list from the server has no text in it, so the whole note is loaded here.
    final noteAsync = ref.watch(noteDetailProvider(noteId));
    return noteAsync.when(
      loading: () => const Scaffold(body: ShimmerList()),
      error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorView(message: friendlyError(e))),
      data: (note) {
        return Scaffold(
          backgroundColor: AppTheme.navy,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(note.title, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                icon: Icon(note.isFavorite ? Icons.favorite : Icons.favorite_border, color: AppTheme.accentPink),
                onPressed: () async {
                  final wasFavorite = note.isFavorite;
                  await ref.read(notesProvider.notifier).toggleFavorite(note.id);
                  ref.invalidate(noteDetailProvider(noteId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(wasFavorite ? 'Removed from favorites' : 'Added to favorites')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.push_pin, color: AppTheme.gold),
                onPressed: () async {
                  await ref.read(notesProvider.notifier).togglePin(note.id);
                  ref.invalidate(noteDetailProvider(noteId));
                },
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') context.push('/notes/${note.id}/edit');
                  if (v == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppTheme.navySurface,
                        title: const Text('Delete Note'),
                        content: const Text('Are you sure?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(notesProvider.notifier).delete(note.id);
                      if (context.mounted) context.pop();
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(_formatDate(note.updatedAt), style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted)),
                  if (note.isPinned) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.push_pin, size: 14, color: AppTheme.gold),
                    const SizedBox(width: 4),
                    const Text('Pinned', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.gold)),
                  ],
                  if (note.isFavorite) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.favorite, size: 14, color: AppTheme.accentPink),
                    const SizedBox(width: 4),
                    const Text('Favorite', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.accentPink)),
                  ],
                ],
              ),
              const GoldDivider(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.navySurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.navyOutline),
                ),
                child: Text(note.content.trim().isEmpty ? 'This note has no text yet. Tap the menu and choose Edit to write in it.' : note.content, style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppTheme.textPrimary, height: 1.8)),
              ),
              if (note.bibleReferences.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: note.bibleReferences.map((ref) {
                    final book = ref['book'] ?? '';
                    final chapter = ref['chapter'];
                    final verse = ref['verse'];
                    final label = [book, if (chapter != null) chapter, if (verse != null) verse].join(' ');
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.book, size: 12, color: AppTheme.gold),
                        const SizedBox(width: 6),
                        Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.gold)),
                      ]),
                    );
                  }).toList(),
                ),
              ],
              if (note.folderName != null) ...[
                const SizedBox(height: 20),
                Row(children: [
                  Icon(Icons.folder_outlined, size: 16, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Text('Folder: ${note.folderName}', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textMuted)),
                ]),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }
}