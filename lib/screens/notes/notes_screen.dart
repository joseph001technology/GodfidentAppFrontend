import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/design_utils.dart';
import '../../models/note.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/premium_components.dart';

// ══════════════════════════════════════════════════════════════════════════
// NOTES LIST SCREEN
// ══════════════════════════════════════════════════════════════════════════

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(notesTopicsProvider);
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/notes/search'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewNoteDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: topicsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e'),
        ),
        data: (topics) => _buildNotesBody(context, ref, topics, notesAsync),
      ),
    );
  }

  Widget _buildNotesBody(
    BuildContext context,
    WidgetRef ref,
    List<NoteTopic> topics,
    AsyncValue<List<Note>> notesAsync,
  ) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(DesignUtils.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topics horizontal scroll
            if (topics.isNotEmpty) ...[
              Text(
                'Topics',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: DesignUtils.spacingMd),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: topics
                      .map((topic) => Padding(
                            padding: const EdgeInsets.only(right: DesignUtils.spacingMd),
                            child: GestureDetector(
                              onTap: () => context.push('/notes/topic/${topic.id}'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: DesignUtils.spacingMd,
                                  vertical: DesignUtils.spacingSm,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.navyVariant,
                                  border: Border.all(
                                    color: AppTheme.gold,
                                    width: 0.5,
                                  ),
                                  borderRadius: DesignUtils.largeRadius,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      topic.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    Text(
                                      '${topic.noteCount} notes',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall?.copyWith(
                                                color: Colors.grey,
                                              ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: DesignUtils.spacingXl),
            ],

            // Recent notes
            Text(
              'Recent Notes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: DesignUtils.spacingMd),
            notesAsync.when(
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error loading notes: $e'),
              data: (notes) {
                if (notes.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(DesignUtils.spacingXl),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Text(
                          '📝',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: DesignUtils.spacingMd),
                        Text(
                          'No notes yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Create your first note to get started',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return _buildNoteCard(context, note);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, Note note) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignUtils.spacingMd),
      child: GestureDetector(
        onTap: () => context.push('/notes/view/${note.id}'),
        child: PremiumCard(
          padding: const EdgeInsets.all(DesignUtils.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: DesignUtils.spacingXs),
                        Text(
                          note.formattedDate,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (note.isPinned)
                        const Icon(Icons.push_pin_rounded, size: 16, color: AppTheme.gold),
                      if (note.isFavorite) const SizedBox(width: DesignUtils.spacingXs),
                      if (note.isFavorite)
                        const Icon(Icons.favorite_rounded, size: 16, color: AppTheme.gold),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: DesignUtils.spacingMd),
              Text(
                note.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
              if (note.bibleReferences.isNotEmpty) ...[
                const SizedBox(height: DesignUtils.spacingMd),
                Wrap(
                  spacing: DesignUtils.spacingSm,
                  children: note.bibleReferences
                      .map((ref) => Chip(
                            label: Text(
                              ref,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            backgroundColor: AppTheme.navySurface,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showNewNoteDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(hintText: 'Title'),
            ),
            const SizedBox(height: DesignUtils.spacingMd),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(hintText: 'Content'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement note creation
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
