import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/note.dart';
import '../../models/rule.dart';
import '../../providers/notes_provider.dart';
import '../../providers/rules_provider.dart';
import '../../widgets/common/app_widgets.dart';

/// Combined Notes + Universal Rules screen accessed from the bottom nav.
/// Uses a TabBar to switch between the two sections so users don't need
/// two separate nav items.
class NotesRulesScreen extends ConsumerStatefulWidget {
  const NotesRulesScreen({super.key});

  @override
  ConsumerState<NotesRulesScreen> createState() => _NotesRulesScreenState();
}

class _NotesRulesScreenState extends ConsumerState<NotesRulesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // — Notes state —
  String _notesTopic = 'All';
  bool _isGridView = false;
  String _notesQuery = '';

  // — Rules state —
  String _rulesCat = 'All';
  String _rulesQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: AppTheme.navySurface,
        elevation: 0,
        title: AnimatedBuilder(
          animation: _tabController,
          builder: (_, __) {
            final isNotes = _tabController.index == 0;
            return Row(
              children: [
                Text(isNotes ? '📝 ' : '📜 ', style: const TextStyle(fontSize: 20)),
                Text(
                  isNotes ? 'Spiritual Notes' : 'Universal Rules',
                  style: const TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          AnimatedBuilder(
            animation: _tabController,
            builder: (_, __) {
              if (_tabController.index == 0) {
                return Row(
                  children: [
                    IconButton(
                      icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view,
                          color: AppTheme.textPrimary),
                      onPressed: () => setState(() => _isGridView = !_isGridView),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppTheme.gold),
                      onPressed: () => context.push('/notes/new'),
                    ),
                  ],
                );
              }
              return IconButton(
                icon: const Icon(Icons.add, color: AppTheme.gold),
                onPressed: () => context.push('/rules/new'),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.gold,
          indicatorWeight: 3,
          labelColor: AppTheme.gold,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 13),
          tabs: const [
            Tab(text: 'Notes'),
            Tab(text: 'Rules'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotesTab(),
          _buildRulesTab(),
        ],
      ),
    );
  }

  // ── NOTES TAB ─────────────────────────────────────────────────────────────

  Widget _buildNotesTab() {
    final notesAsync = ref.watch(notesProvider);
    final topicsAsync = ref.watch(notesTopicsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(notesProvider.notifier).refresh();
        ref.invalidate(notesTopicsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(
              hint: 'Search notes & topics...',
              onChanged: (v) => setState(() => _notesQuery = v.toLowerCase()),
            ),
            const SizedBox(height: 16),
            _buildTopicPills(topicsAsync),
            const SizedBox(height: 20),
            notesAsync.when(
              loading: () => const LoadingShimmer(height: 200),
              error: (e, _) => ErrorView(message: e.toString()),
              data: (notes) {
                final filtered = notes.where((n) {
                  final matchesTopic = _notesTopic == 'All' || n.topicNames.contains(_notesTopic);
                  final matchesQuery = _notesQuery.isEmpty ||
                      n.title.toLowerCase().contains(_notesQuery) ||
                      n.content.toLowerCase().contains(_notesQuery);
                  return matchesTopic && matchesQuery;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyView(
                    title: notes.isEmpty ? 'No notes yet' : 'No matching notes',
                    subtitle: notes.isEmpty ? 'Tap + to write your first note' : 'Try a different search or topic',
                    icon: Icons.edit_note,
                  );
                }
                return _isGridView
                    ? _buildGridNotes(filtered)
                    : _buildListNotes(filtered);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicPills(AsyncValue<List<NoteTopic>> topicsAsync) {
    return topicsAsync.when(
      loading: () => const SizedBox(height: 38),
      error: (_, __) => const SizedBox.shrink(),
      data: (topics) => SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: topics.length + 1,
          itemBuilder: (context, i) {
            final label = i == 0 ? 'All' : topics[i - 1].name;
            final isSelected = _notesTopic == label;
            return GestureDetector(
              onTap: () => setState(() => _notesTopic = label),
              child: _pill(label, isSelected),
            );
          },
        ),
      ),
    );
  }

  Widget _buildListNotes(List<Note> notes) {
    return Column(
      children: notes.map((n) => _buildNoteCard(n)).toList(),
    );
  }

  Widget _buildGridNotes(List<Note> notes) {
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
      itemBuilder: (_, i) => _buildNoteCard(notes[i]),
    );
  }

  Widget _buildNoteCard(Note note) {
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
                    note.topicName.isNotEmpty ? note.topicName : 'General',
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.softBlue),
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
              style: const TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              note.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // ── RULES TAB ─────────────────────────────────────────────────────────────

  Widget _buildRulesTab() {
    final rulesAsync = ref.watch(rulesProvider);
    final categoriesAsync = ref.watch(ruleCategoriesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(rulesProvider);
        ref.invalidate(ruleCategoriesProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Motivational banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2D1B69), Color(0xFF14142A)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PERMANENT DISCIPLINE',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.gold,
                        letterSpacing: 1.2),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '"He who heeds instruction is on the path to life."',
                    style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textPrimary),
                  ),
                  SizedBox(height: 4),
                  Text('— Proverbs 10:17',
                      style: TextStyle(
                          fontFamily: 'Lora',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.gold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSearchBar(
              hint: 'Search rules...',
              onChanged: (v) => setState(() => _rulesQuery = v.toLowerCase()),
            ),
            const SizedBox(height: 16),
            _buildCategoryPills(categoriesAsync),
            const SizedBox(height: 20),
            rulesAsync.when(
              loading: () => const LoadingShimmer(height: 200),
              error: (e, _) => ErrorView(message: e.toString()),
              data: (rules) {
                final filtered = rules.where((r) {
                  final matchesCat =
                      _rulesCat == 'All' || (r.categoryName ?? '') == _rulesCat;
                  final matchesQuery = _rulesQuery.isEmpty ||
                      r.title.toLowerCase().contains(_rulesQuery) ||
                      (r.description ?? '').toLowerCase().contains(_rulesQuery);
                  return matchesCat && matchesQuery;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyView(
                    title: rules.isEmpty ? 'No rules yet' : 'No matching rules',
                    subtitle: rules.isEmpty
                        ? 'Tap + to add your first rule'
                        : 'Try a different search or category',
                    icon: Icons.rule,
                  );
                }
                return Column(
                  children: filtered.map((r) => _buildRuleItem(r)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPills(AsyncValue<List<RuleCategory>> categoriesAsync) {
    return categoriesAsync.when(
      loading: () => const SizedBox(height: 38),
      error: (_, __) => const SizedBox.shrink(),
      data: (cats) => SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: cats.length + 1,
          itemBuilder: (_, i) {
            final label = i == 0 ? 'All' : cats[i - 1].name;
            final isSelected = _rulesCat == label;
            return GestureDetector(
              onTap: () => setState(() => _rulesCat = label),
              child: _pill(label, isSelected),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRuleItem(Rule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: rule.isCompletedToday
              ? AppTheme.emerald.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              await ref.read(rulesProvider.notifier).toggleToday(rule.id);
              ref.invalidate(todayRulesProvider);
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: rule.isCompletedToday
                    ? AppTheme.emerald
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check,
                  size: 16,
                  color: rule.isCompletedToday ? Colors.white : Colors.transparent),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.title,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: rule.isCompletedToday ? AppTheme.textMuted : AppTheme.textPrimary,
                    decoration:
                        rule.isCompletedToday ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (rule.description != null && rule.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(rule.description!,
                      style: const TextStyle(
                          fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted)),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (rule.categoryName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(rule.categoryName!,
                            style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.gold)),
                      ),
                    if (rule.currentStreak > 0) ...[
                      const SizedBox(width: 8),
                      Text('🔥 ${rule.currentStreak}d',
                          style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.gold)),
                    ],
                    if (rule.isPinned) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.push_pin, color: AppTheme.gold, size: 12),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppTheme.textMuted, size: 18),
            onPressed: () => _showRuleActions(rule),
          ),
        ],
      ),
    );
  }

  void _showRuleActions(Rule rule) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navySurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppTheme.gold),
              title: const Text('Edit Rule', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                context.push('/rules/${rule.id}/edit');
              },
            ),
            ListTile(
              leading: Icon(
                rule.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: AppTheme.accentPink,
              ),
              title: Text(rule.isFavorite ? 'Remove Favorite' : 'Mark Favorite',
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                ref.read(rulesProvider.notifier).toggleFavorite(rule.id);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Rule', style: TextStyle(color: Colors.red)),
              onTap: () {
                ref.read(rulesProvider.notifier).delete(rule.id);
                ref.invalidate(todayRulesProvider);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared Helpers ─────────────────────────────────────────────────────────

  Widget _buildSearchBar({required String hint, required ValueChanged<String> onChanged}) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      ),
    );
  }

  Widget _pill(String label, bool isSelected) {
    return Container(
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
    );
  }
}
