import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/bible_books.dart';
import '../../core/dio_client.dart';
import '../../core/theme.dart';
import '../../providers/bible_provider.dart';
import '../../services/reader_settings.dart';
import '../bible/chapter_picker.dart';

/// Search everything. Book names come FIRST (instant, offline), then what the
/// server finds inside your Bible, notes, rules, prayers, devotionals, reminders.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _activeFilter = 'All';
  Timer? _debounce;
  Future<List<_Hit>>? _results;
  List<String> _recents = [];

  final List<String> _filters = ['All', 'Books', 'Bible', 'Notes', 'Rules', 'Prayers', 'Devotionals', 'Reminders'];

  @override
  void initState() {
    super.initState();
    RecentSearches.load().then((r) {
      if (mounted) setState(() => _recents = r);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _run(String v) {
    _searchController.text = v;
    _searchController.selection = TextSelection.collapsed(offset: v.length);
    _onQueryChanged(v);
  }

  void _onQueryChanged(String v) {
    final q = v.trim();
    _debounce?.cancel();
    setState(() {
      _query = q;
      if (q.isEmpty) _results = null;
    });
    if (q.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _results = _search(q));
    });
  }

  /// Server search: GET /api/search/?q=...&translation=...
  Future<List<_Hit>> _search(String q) async {
    final translation = ref.read(selectedTranslationProvider);
    final res = await DioClient.instance.get('/api/search/', queryParameters: {'q': q, 'translation': translation});
    final data = (res.data is Map ? (res.data['data'] ?? {}) : {}) as Map;
    List<Map> list(String k) => (data[k] is List) ? (data[k] as List).whereType<Map>().toList() : <Map>[];

    final out = <_Hit>[];
    for (final b in list('bible')) {
      final reference = '${b['reference']}';
      final sp = reference.lastIndexOf(' ');
      var route = '/bible';
      if (sp > 0) {
        final book = reference.substring(0, sp);
        final cv = reference.substring(sp + 1).split(':');
        final ch = int.tryParse(cv.first);
        if (ch != null) {
          route = '/bible/chapter?book=${Uri.encodeComponent(book)}&chapter=$ch'
              '&translation=${b['translation'] ?? translation}'
              '${cv.length > 1 ? '&verse=${cv[1].split('-').first}' : ''}';
        }
      }
      out.add(_Hit('Bible', reference, '${b['text'] ?? ''}', route));
    }
    for (final n in list('notes')) {
      out.add(_Hit('Notes', '${n['title']}', '${n['snippet'] ?? ''}', '/notes/${n['id']}'));
    }
    for (final r in list('rules')) {
      out.add(_Hit('Rules', '${r['title']}', '${r['snippet'] ?? ''}', '/rules/${r['id']}/edit'));
    }
    for (final p in list('prayers')) {
      out.add(_Hit('Prayers', '${p['title']}', '${p['snippet'] ?? ''}', '/prayer/${p['id']}'));
    }
    for (final j in list('prayer_journal')) {
      out.add(_Hit('Prayers', '${j['title']}', 'Prayer journal', '/prayer'));
    }
    for (final d in list('devotionals')) {
      out.add(_Hit('Devotionals', '${d['title']}', '${d['snippet'] ?? ''}', '/more/devotionals/${d['id']}'));
    }
    for (final r in list('reminders')) {
      out.add(_Hit('Reminders', '${r['title']}', '${r['date'] ?? ''}', '/reminders/${r['id']}'));
    }
    RecentSearches.add(q).then((r) {
      if (mounted) setState(() => _recents = r);
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Search',
            style: TextStyle(fontFamily: 'Lora', fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Book, verse, note, prayer, rule...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.goldDark),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppTheme.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        _onQueryChanged('');
                      },
                    )
                  : null,
              fillColor: AppTheme.navySurface,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.navyOutline),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              itemBuilder: (context, i) {
                final f = _filters[i];
                final isSelected = _activeFilter == f;
                return GestureDetector(
                  onTap: () => setState(() => _activeFilter = f),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.gold : AppTheme.navySurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppTheme.gold : AppTheme.navyOutline),
                    ),
                    child: Text(f,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppTheme.inkNavy : AppTheme.textPrimary,
                        )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          if (_query.isEmpty) _buildRecent() else _buildResults(),
        ]),
      ),
    );
  }

  Widget _buildRecent() {
    if (_recents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text('Try a book (John), a reference (Psalm 23), or any word.',
              textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted)),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(
          child: Text('Recent searches',
              style: TextStyle(fontFamily: 'Lora', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ),
        TextButton(
          onPressed: () async {
            await RecentSearches.clear();
            if (mounted) setState(() => _recents = []);
          },
          child: const Text('Clear'),
        ),
      ]),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final item in _recents)
          GestureDetector(
            onTap: () => _run(item),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.navySurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.navyOutline),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.history, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Text(item, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textPrimary)),
              ]),
            ),
          ),
      ]),
    ]);
  }

  Widget _buildResults() {
    final translation = ref.watch(selectedTranslationProvider);
    final books = (_activeFilter == 'All' || _activeFilter == 'Books') ? BibleBooks.parse(_query) : <BookMatch>[];
    final showServer = _activeFilter != 'Books';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (books.isNotEmpty) ...[
        _sectionLabel('BOOKS'),
        for (final m in books.take(8))
          _card(
            type: 'Book',
            title: m.label,
            desc: '${m.book.testament == 'OT' ? 'Old' : 'New'} Testament · ${m.book.chapters} chapters',
            onTap: () {
              RecentSearches.add(_query);
              if (m.hasChapter) {
                openChapter(context, m.book.name, m.chapter!, translation, verse: m.verse);
              } else {
                showChapterPickerFor(context, m.book, translation);
              }
            },
          ),
      ],
      if (showServer)
        FutureBuilder<List<_Hit>>(
          future: _results,
          builder: (context, snap) {
            if (_results == null || snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: CircularProgressIndicator(color: AppTheme.gold),
                ),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(friendlyError(snap.error!), textAlign: TextAlign.center)),
              );
            }
            final hits = (snap.data ?? []).where((h) => _activeFilter == 'All' || h.type == _activeFilter).toList();
            if (hits.isEmpty) {
              if (books.isNotEmpty) return const SizedBox.shrink();
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(children: [
                    Icon(Icons.search_off, size: 48, color: AppTheme.textMuted),
                    SizedBox(height: 12),
                    Text('No matching results found', style: TextStyle(color: AppTheme.textMuted)),
                  ]),
                ),
              );
            }
            // Group by type, keeping the order the server gave.
            final types = <String>[];
            for (final h in hits) {
              if (!types.contains(h.type)) types.add(h.type);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final t in types) ...[
                _sectionLabel(t.toUpperCase()),
                for (final h in hits.where((x) => x.type == t))
                  _card(type: h.type, title: h.title, desc: h.desc, onTap: () => context.push(h.route)),
              ],
            ]);
          },
        ),
    ]);
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppTheme.textMuted)),
      );

  Widget _card({required String type, required String title, required String desc, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.navyOutline),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontFamily: 'Lora', fontSize: 16, fontWeight: FontWeight.bold)),
        subtitle: desc.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ),
        trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.goldDark, size: 14),
        onTap: onTap,
      ),
    );
  }
}

class _Hit {
  final String type;
  final String title;
  final String desc;
  final String route;
  const _Hit(this.type, this.title, this.desc, this.route);
}
