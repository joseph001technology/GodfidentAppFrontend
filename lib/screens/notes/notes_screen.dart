import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/note.dart';
import '../../providers/notes_provider.dart';
import '../../widgets/common/app_widgets.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _selectedTopic = 'All';
  bool _isGridView = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);
    final topicsAsync = ref.watch(notesTopicsProvider);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Text('📝 ', style: TextStyle(fontSize: 20)),
            Text(
              'Spiritual Notes',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, color: AppTheme.textPrimary),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.gold),
            onPressed: () => context.push('/notes/new'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(notesProvider.notifier).refresh();
          ref.invalidate(notesTopicsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search notes & topics...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                  fillColor: AppTheme.navySurface,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Topic pills — pulled from GET /api/notes/topics/, i.e. the
              // topics you've actually created, not a hardcoded list.
              topicsAsync.when(
                loading: () => const SizedBox(height: 38),
                error: (_, __) => const SizedBox.shrink(),
                data: (topics) => SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: topics.length + 1,
                    itemBuilder: (context, i) {
                      final label = i == 0 ? 'All' : topics[i - 1].name;
                      final isSelected = _selectedTopic == label;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedTopic = label),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.gold : AppTheme.navySurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppTheme.gold : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppTheme.navy : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Notes Listing
              notesAsync.when(
                loading: () => const LoadingShimmer(height: 200),
                error: (e, _) => ErrorView(message: e.toString()),
                data: (notes) {
                  final filtered = notes.where((n) {
                    final matchesTopic = _selectedTopic == 'All' || n.topicNames.contains(_selectedTopic);
                    final matchesQuery = _searchQuery.isEmpty ||
                        n.title.toLowerCase().contains(_searchQuery) ||
                        n.content.toLowerCase().contains(_searchQuery);
                    return matchesTopic && matchesQuery;
                  }).toList();

                  if (filtered.isEmpty) {
                    return EmptyView(
                      title: notes.isEmpty ? 'No notes yet' : 'No matching notes',
                      subtitle: notes.isEmpty
                          ? 'Tap + to write your first note'
                          : 'Try a different search or topic',
                      icon: Icons.edit_note,
                    );
                  }

                  return _isGridView ? _buildGridNotes(context, filtered) : _buildListNotes(context, filtered);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListNotes(BuildContext context, List<Note> notes) {
    return Column(
      children: notes.map((n) => _buildNoteCard(context, n)).toList(),
    );
  }

  Widget _buildGridNotes(BuildContext context, List<Note> notes) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: notes.length,
      itemBuilder: (context, i) => _buildNoteCard(context, notes[i]),
    );
  }

  Widget _buildNoteCard(BuildContext context, Note note) {
    return GestureDetector(
      onTap: () => context.push('/notes/${note.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.softBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    note.topicName.isNotEmpty ? note.topicName : 'Devotion',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.softBlue),
                  ),
                ),
                if (note.isPinned) const Icon(Icons.push_pin, color: AppTheme.gold, size: 14),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Lora', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              note.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}