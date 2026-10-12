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
            title: const SizedBox.shrink(),
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
                icon: Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: AppTheme.gold),
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
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 48),
                children: [
                  Text(
                    note.title.isEmpty ? 'Untitled note' : note.title,
                    style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.access_time, size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 6),
                      Text(_formatDate(note.updatedAt),
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted)),
                    ]),
                    if (note.isPinned)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.push_pin, size: 14, color: AppTheme.gold),
                        const SizedBox(width: 4),
                        Text('Pinned', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.goldAccent)),
                      ]),
                    if (note.isFavorite)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.favorite, size: 14, color: AppTheme.accentPink),
                        const SizedBox(width: 4),
                        Text('Favorite', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.accentPink)),
                      ]),
                    if (note.folderName != null && note.folderName!.isNotEmpty)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.folder_outlined, size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(note.folderName!,
                            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted)),
                      ]),
                  ]),
                  if (note.topicNames.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      for (final t in note.topicNames)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.softBlue.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(t,
                              style: TextStyle(
                                  fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.softBlue)),
                        ),
                    ]),
                  ],
                  const GoldDivider(),
                  if (note.content.trim().isEmpty)
                    Text(
                      'This note has no text yet. Tap the menu and choose Edit to write in it.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textMuted, height: 1.6),
                    )
                  else
                    SelectableText(
                      note.content,
                      style: TextStyle(fontFamily: 'Lora', fontSize: 17, color: AppTheme.textPrimary, height: 1.85),
                    ),
                  if (note.bibleReferences.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Row(children: [
                      Icon(Icons.menu_book_rounded, size: 16, color: AppTheme.goldAccent),
                      const SizedBox(width: 6),
                      Text('Scripture',
                          style: TextStyle(
                              fontFamily: 'Lora', fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: note.bibleReferences.map((r) {
                        final book = r['book'] ?? '';
                        final chapter = r['chapter'];
                        final verse = r['verse'];
                        final label = [book, if (chapter != null) chapter, if (verse != null) verse].join(' ');
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  fontFamily: 'Lora',
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                  color: AppTheme.goldAccent)),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
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