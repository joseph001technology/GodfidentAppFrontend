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
            _notesSummary(notesAsync.valueOrNull),
            const SizedBox(height: 14),
            _buildSearchBar(
              hint: 'Search notes & topics...',
              onChanged: (v) => setState(() => _notesQuery = v.toLowerCase()),
            ),
            const SizedBox(height: 16),
            _buildTopicPills(topicsAsync),
            const SizedBox(height: 20),
            notesAsync.when(
              loading: () => const LoadingShimmer(height: 200),
              error: (e, _) => ErrorView(message: friendlyError(e)),
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

  Widget _summaryCard({required IconData icon, required Color color, required String title, required String sub, double? progress}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.16), AppTheme.navySurface], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontFamily: 'Lora', fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary)),
            if (progress != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: progress, minHeight: 6, color: color, backgroundColor: color.withValues(alpha: 0.15)),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _notesSummary(List<Note>? notes) {
    final n = notes?.length ?? 0;
    final pinned = notes?.where((x) => x.isPinned).length ?? 0;
    return _summaryCard(
      icon: Icons.edit_note,
      color: AppTheme.softBlue,
      title: n == 0 ? 'Your notes' : '$n note${n == 1 ? '' : 's'}',
      sub: n == 0 ? 'Write down what God is teaching you.' : '${pinned == 0 ? 'None' : pinned} pinned',
    );
  }

  Widget _rulesSummary(List<Rule>? rules) {
    final n = rules?.length ?? 0;
    final done = rules?.where((r) => r.isCompletedToday).length ?? 0;
    return _summaryCard(
      icon: Icons.rule,
      color: AppTheme.accentPurple,
      title: n == 0 ? 'Your rules' : '$done of $n kept today',
      sub: n == 0 ? 'Rules you hold to every day.' : (done == n ? 'Every rule kept today. Well done.' : 'Tap the circle on a rule when you keep it.'),
      progress: n == 0 ? null : done / n,
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
      children: [for (var i = 0; i < notes.length; i++) _buildNoteCard(notes[i], i + 1)],
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
      itemBuilder: (_, i) => _buildNoteCard(notes[i], i + 1, compact: true),
    );
  }

  /// Two-digit number badge ("01", "02" ...) used by notes and rules.
  Widget _numberBadge(int n, {Color color = AppTheme.gold, double size = 38}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size / 3),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        n.toString().padLeft(2, '0'),
        style: TextStyle(fontFamily: 'Lora', fontSize: size * 0.4, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  String _shortDate(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Widget _buildNoteCard(Note note, int number, {bool compact = false}) {
    final topics = note.topicNames;
    return GestureDetector(
      onTap: () => context.push('/notes/${note.id}'),
      child: Container(
        margin: EdgeInsets.only(bottom: compact ? 0 : 12),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.navyOutline),
          boxShadow: [BoxShadow(color: AppTheme.inkNavy.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 5, color: note.isPinned ? AppTheme.gold : AppTheme.softBlue.withValues(alpha: 0.5)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _numberBadge(number, color: AppTheme.softBlue, size: compact ? 32 : 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          note.title.isEmpty ? 'Untitled note' : note.title,
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Lora', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(_shortDate(note.updatedAt),
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted)),
                      ]),
                    ),
                    if (note.isPinned) const Icon(Icons.push_pin, color: AppTheme.gold, size: 16),
                    if (note.isFavorite) const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.favorite, color: AppTheme.accentPink, size: 15),
                    ),
                  ]),
                  if (note.content.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      note.content,
                      maxLines: compact ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textSecondary, height: 1.45),
                    ),
                  ],
                  if (topics.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      for (final t in topics.take(3))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.softBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(t,
                              style: const TextStyle(
                                  fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.softBlue)),
                        ),
                    ]),
                  ],
                ]),
              ),
            ),
          ]),
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
            _rulesSummary(rulesAsync.valueOrNull),
            const SizedBox(height: 14),
            // Motivational banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // was a dark [#2D1B69, #14142A] gradient — flattened,
                // same reasoning as the other "motivational banner" cards
                color: AppTheme.navySurface,
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
              error: (e, _) => ErrorView(message: friendlyError(e)),
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
                  children: [for (var i = 0; i < filtered.length; i++) _buildRuleItem(filtered[i], i + 1)],
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

  Widget _buildRuleItem(Rule rule, int number) {
    final done = rule.isCompletedToday;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: done ? AppTheme.emerald.withValues(alpha: 0.45) : AppTheme.navyOutline),
        boxShadow: [BoxShadow(color: AppTheme.inkNavy.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 5, color: done ? AppTheme.emerald : AppTheme.accentPurple.withValues(alpha: 0.5)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _numberBadge(number, color: done ? AppTheme.emerald : AppTheme.accentPurple),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      rule.title,
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: done ? AppTheme.textMuted : AppTheme.textPrimary,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (rule.description != null && rule.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(rule.description!,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4)),
                    ],
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      if (rule.categoryName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(rule.categoryName!,
                              style: const TextStyle(
                                  fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.goldDark)),
                        ),
                      if (rule.currentStreak > 0)
                        Text('\u{1F525} ${rule.currentStreak} day streak',
                            style: const TextStyle(
                                fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.goldDark)),
                      if (rule.isPinned) const Icon(Icons.push_pin, color: AppTheme.gold, size: 12),
                    ]),
                  ]),
                ),
                Column(children: [
                  GestureDetector(
                    onTap: () async {
                      await ref.read(rulesProvider.notifier).toggleToday(rule.id);
                      ref.invalidate(todayRulesProvider);
                    },
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(4, 2, 8, 0),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: done ? AppTheme.emerald : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: done ? AppTheme.emerald : AppTheme.textMuted, width: 1.5),
                      ),
                      child: Icon(Icons.check, size: 16, color: done ? Colors.white : Colors.transparent),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.more_vert, color: AppTheme.textMuted, size: 18),
                    onPressed: () => _showRuleActions(rule),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
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
          borderSide: BorderSide(color: AppTheme.navyOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.navyOutline),
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
          color: isSelected ? AppTheme.gold : AppTheme.navyOutline,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isSelected ? AppTheme.inkNavy : AppTheme.textPrimary,
        ),
      ),
    );
  }
}
