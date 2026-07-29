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
    final notesAsync = ref.watch(notesProvider);
    return notesAsync.when(
      loading: () => const Scaffold(body: ShimmerList()),
      error: (e, _) => Scaffold(body: ErrorView(message: e.toString())),
      data: (notes) {
        final note = notes.firstWhere((n) => n.id == noteId, orElse: () => notes.first);
        return Scaffold(
          backgroundColor: AppTheme.navy,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(note.title, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(icon: Icon(note.isFavorite ? Icons.favorite : Icons.favorite_border, color: AppTheme.accentPink), onPressed: () {
                ref.read(notesProvider.notifier).toggleFavorite(note.id);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(note.isFavorite ? 'Removed from favorites' : 'Added to favorites')));
              }),
              IconButton(icon: const Icon(Icons.push_pin, color: AppTheme.gold), onPressed: () => ref.read(notesProvider.notifier).togglePin(note.id)),
              PopupMenuButton<String>(onSelected: (v) async {
                if (v == 'edit') context.push('/notes/${note.id}/edit');
                if (v == 'delete') {
                  final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(backgroundColor: AppTheme.navySurface, title: const Text('Delete Note'), content: const Text('Are you sure?'), actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                  ]));
                  if (confirm == true) { await ref.read(notesProvider.notifier).delete(note.id); if (context.mounted) context.pop(); }
                }
              }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red)))]),
            ],
          ),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            if (note.topicNames.isNotEmpty) ...[
              Wrap(spacing: 8, runSpacing: 6, children: note.topicNames.map((t) {
                return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: AppTheme.softBlue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.softBlue.withValues(alpha: 0.3))), child: Text(t, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.softBlue)));
              }).toList()),
              const SizedBox(height: 16),
              const GoldDivider(),
            ],
            Row(children: [
              const Icon(Icons.access_time, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(_formatDate(note.updatedAt), style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted)),
              if (note.isPinned) ...[const SizedBox(width: 16), const Icon(Icons.push_pin, size: 14, color: AppTheme.gold), const SizedBox(width: 4), const Text('Pinned', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.gold))],
              if (note.isFavorite) ...[const SizedBox(width: 16), const Icon(Icons.favorite, size: 14, color: AppTheme.accentPink), const SizedBox(width: 4), const Text('Favorite', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.accentPink))],
            ]),
            const GoldDivider(),
            Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.06))), child: Text(note.content, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppTheme.textPrimary, height: 1.8))),
            if (note.folderName != null) ...[
              const SizedBox(height: 20),
              Row(children: [const Icon(Icons.folder_outlined, size: 16, color: AppTheme.textMuted), const SizedBox(width: 8), Text('Folder: ${note.folderName}', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textMuted))]),
            ],
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () async {
              await ref.read(notesProvider.notifier).archiveNote(note.id);
              if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note archived'))); context.pop(); }
            }, icon: const Icon(Icons.archive_outlined, size: 18), label: const Text('Archive Note'), style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textMuted, side: BorderSide(color: AppTheme.textMuted.withValues(alpha: 0.3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 14)))),
          ]),
        );
      },
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return dateStr; }
  }
}