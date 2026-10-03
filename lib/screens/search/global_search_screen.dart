import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/dio_client.dart';

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

  final List<String> _filters = ['All', 'Bible', 'Notes', 'Rules', 'Prayers', 'Reminders'];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Global Search',
          style: TextStyle(
            fontFamily: 'Lora',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Search scriptures, notes, prayers, rules...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.gold),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                fillColor: AppTheme.navySurface,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppTheme.navyOutline),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Filter Chips
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
                        border: Border.all(
                          color: isSelected ? AppTheme.gold : AppTheme.navyOutline,
                        ),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppTheme.inkNavy : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            if (_query.isEmpty)
              _buildRecentSearches()
            else
              _buildSearchResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSearches() {
    final recents = ['Philippians 4:13', 'Grace & Faith', 'Morning Prayer', 'Rule: No social media'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Searches',
          style: TextStyle(fontFamily: 'Lora', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: recents.map((item) {
            return GestureDetector(
              onTap: () {
                _searchController.text = item;
                setState(() => _query = item.toLowerCase());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.navySurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.navyOutline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(item, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
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

  /// Real search against the Django backend: GET /api/search/?q=...
  Future<List<_Hit>> _search(String q) async {
    final res = await DioClient.instance.get('/api/search/', queryParameters: {'q': q});
    final data = (res.data is Map ? (res.data['data'] ?? {}) : {}) as Map;
    List<Map> list(String k) => (data[k] is List) ? (data[k] as List).whereType<Map>().toList() : <Map>[];

    final out = <_Hit>[];
    for (final b in list('bible')) {
      final ref = '${b['reference']}';
      // "John 3:16" -> book "John", chapter 3
      final sp = ref.lastIndexOf(' ');
      final cv = sp > 0 ? ref.substring(sp + 1).split(':') : <String>[];
      final route = (sp > 0 && cv.isNotEmpty)
          ? '/bible/chapter?book=${Uri.encodeComponent(ref.substring(0, sp))}&chapter=${cv.first}&translation=${b['translation'] ?? 'KJV'}'
          : '/bible';
      out.add(_Hit('Bible', ref, '${b['text'] ?? ''}', route));
    }
    for (final n in list('notes')) {
      out.add(_Hit('Notes', '${n['title']}', '', '/notes/${n['id']}'));
    }
    for (final r in list('rules')) {
      out.add(_Hit('Rules', '${r['title']}', '', '/rules/${r['id']}/edit'));
    }
    for (final j in list('prayer_journal')) {
      out.add(_Hit('Prayers', '${j['title']}', '', '/prayer/${j['id']}'));
    }
    for (final r in list('reminders')) {
      out.add(_Hit('Reminders', '${r['title']}', '${r['date'] ?? ''}', '/reminders/${r['id']}'));
    }
    return out;
  }

  Widget _buildSearchResults() {
    return FutureBuilder<List<_Hit>>(
      future: _results,
      builder: (context, snap) {
        if (_results == null || snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: AppTheme.gold),
            ),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text(friendlyError(snap.error!), textAlign: TextAlign.center)),
          );
        }
        final hits = (snap.data ?? [])
            .where((h) => _activeFilter == 'All' || h.type == _activeFilter)
            .toList();
        if (hits.isEmpty) {
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
        return Column(children: [
          for (final h in hits)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.navySurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.navyOutline),
              ),
              child: ListTile(
                title: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(h.type,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.goldDark)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(h.title,
                        style: const TextStyle(fontFamily: 'Lora', fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ]),
                subtitle: h.desc.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(h.desc,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ),
                trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.goldDark, size: 14),
                onTap: () => context.push(h.route),
              ),
            ),
        ]);
      },
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
