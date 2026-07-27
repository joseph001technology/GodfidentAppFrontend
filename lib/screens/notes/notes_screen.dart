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

  final List<String> _topics = [
    'All',
    'Faith',
    'Prayer',
    'Grace',
    'Leadership',
    'Business',
    'Church',
    'Devotion',
    'Relationships'
  ];

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);

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
        onRefresh: () async => ref.read(notesProvider.notifier).refresh(),
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
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Unlimited Topics Selector Bar
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _topics.length,
                  itemBuilder: (context, i) {
                    final topic = _topics[i];
                    final isSelected = _selectedTopic == topic;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTopic = topic),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.gold : AppTheme.navySurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppTheme.gold : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Text(
                          topic,
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

              const SizedBox(height: 20),

              // Notes Listing
              notesAsync.when(
                loading: () => const LoadingShimmer(height: 200),
                error: (e, _) => ErrorView(message: e.toString()),
                data: (notes) {
                  var filtered = notes.where((n) {
                    final matchesTopic = _selectedTopic == 'All' || (n.topicName ?? '').toLowerCase() == _selectedTopic.toLowerCase();
                    final matchesQuery = _searchQuery.isEmpty || n.title.toLowerCase().contains(_searchQuery) || n.content.toLowerCase().contains(_searchQuery);
                    return matchesTopic && matchesQuery;
                  }).toList();

                  if (filtered.isEmpty) {
                    return _buildDefaultNotes(context);
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
          border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                    color: AppTheme.softBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    note.topicName ?? 'Devotion',
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

  Widget _buildDefaultNotes(BuildContext context) {
    final list = [
      {'title': 'Walking in Divine Grace', 'topic': 'Grace', 'content': 'Ephesians 2:8 - For by grace you have been saved through faith. It is not of yourselves; it is the gift of God.', 'pinned': true},
      {'title': 'Kingdom Leadership Principles', 'topic': 'Leadership', 'content': 'A true leader serves with humility. Jesus washed the feet of His disciples to set the ultimate example.', 'pinned': false},
      {'title': 'Faith in Times of Trial', 'topic': 'Faith', 'content': 'Hebrews 11:1 - Now faith is confidence in what we hope for and assurance about what we do not see.', 'pinned': false},
      {'title': 'Biblical Stewardship in Business', 'topic': 'Business', 'content': 'Honor the Lord with your wealth and with the firstfruits of all your produce.', 'pinned': false},
    ];

    return Column(
      children: list.map((n) {
        final isPinned = n['pinned'] as bool;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.navySurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                      color: AppTheme.softBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      n['topic'] as String,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.softBlue),
                    ),
                  ),
                  if (isPinned) const Icon(Icons.push_pin, color: AppTheme.gold, size: 14),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                n['title'] as String,
                style: const TextStyle(fontFamily: 'Lora', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                n['content'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted, height: 1.4),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
