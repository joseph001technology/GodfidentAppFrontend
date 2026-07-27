import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _activeFilter = 'All';

  final List<String> _filters = ['All', 'Bible', 'Notes', 'Rules', 'Prayers', 'Reminders'];

  @override
  void dispose() {
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
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
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
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
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
                          color: isSelected ? AppTheme.gold : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Text(
                        f,
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
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
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

  Widget _buildSearchResults() {
    final mockResults = [
      {'type': 'Bible', 'title': 'Philippians 4:13', 'desc': 'I can do all things through Christ who strengthens me.', 'route': '/bible'},
      {'type': 'Notes', 'title': 'Walking in Divine Grace', 'desc': 'Saved by grace through faith in Christ.', 'route': '/notes'},
      {'type': 'Rules', 'title': 'No Social Media Before Prayer', 'desc': 'Protect morning attention for God.', 'route': '/rules'},
      {'type': 'Prayers', 'title': 'Family Unity & Peace', 'desc': 'Praying for God’s guidance in our home.', 'route': '/prayer'},
      {'type': 'Reminders', 'title': 'Morning Prayer', 'desc': 'Daily at 6:00 AM', 'route': '/reminders'},
    ].where((r) {
      final matchesFilter = _activeFilter == 'All' || r['type'] == _activeFilter;
      final matchesQuery = (r['title'] as String).toLowerCase().contains(_query) || (r['desc'] as String).toLowerCase().contains(_query);
      return matchesFilter && matchesQuery;
    }).toList();

    if (mockResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: AppTheme.textMuted),
              SizedBox(height: 12),
              Text('No matching results found', style: TextStyle(fontFamily: 'Inter', color: AppTheme.textMuted)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: mockResults.map((r) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.navySurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    r['type'] as String,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.gold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  r['title'] as String,
                  style: const TextStyle(fontFamily: 'Lora', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                r['desc'] as String,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.gold, size: 14),
            onTap: () => context.push(r['route'] as String),
          ),
        );
      }).toList(),
    );
  }
}
