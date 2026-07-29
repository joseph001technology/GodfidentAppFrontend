import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/prayer.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/common/app_widgets.dart';
import '../../widgets/common/prayer_timer_widget.dart';

class PrayerListScreen extends ConsumerStatefulWidget {
  const PrayerListScreen({super.key});

  @override
  ConsumerState<PrayerListScreen> createState() => _PrayerListScreenState();
}

class _PrayerListScreenState extends ConsumerState<PrayerListScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Requests', 'Answered', 'Thanksgiving', 'Family', 'Healing'];

  @override
  Widget build(BuildContext context) {
    final prayersAsync = ref.watch(prayerListProvider);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Text('🙏 ', style: TextStyle(fontSize: 20)),
            Text(
              'Prayer Hub',
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
            icon: const Icon(Icons.bar_chart, color: AppTheme.gold),
            onPressed: () => context.push('/prayer/stats'),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.gold),
            onPressed: () async {
              await context.push('/prayer/new');
              ref.read(prayerListProvider.notifier).load();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.gold,
        onRefresh: () => ref.read(prayerListProvider.notifier).load(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Prayer Timer Quick Banner (functional)
              PrayerTimerWidget(showCompact: true, initialSeconds: 300),

              const SizedBox(height: 20),

              // Category Pills
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, i) {
                    final cat = _categories[i];
                    final isSelected = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.gold : AppTheme.navySurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? AppTheme.gold : Colors.white.withOpacity(0.08)),
                        ),
                        child: Text(
                          cat,
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

              // Prayers List
              prayersAsync.when(
                loading: () => const LoadingShimmer(height: 200),
                error: (e, _) => ErrorView(message: e.toString()),
                data: (prayers) {
                  var filtered = prayers.where((p) {
                    if (_selectedCategory == 'Answered') return p.isAnswered;
                    if (_selectedCategory == 'Requests') return !p.isAnswered;
                    if (_selectedCategory == 'All') return true;
                    return p.prayerType.toLowerCase() == _selectedCategory.toLowerCase();
                  }).toList();

                  if (filtered.isEmpty) {
                    return _buildDefaultPrayersList(context);
                  }

                  return Column(
                    children: filtered.map((p) => _buildPrayerCard(context, ref, p)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerCard(BuildContext context, WidgetRef ref, Prayer prayer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: prayer.isAnswered ? AppTheme.emerald.withOpacity(0.4) : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    prayer.isAnswered ? Icons.check_circle : Icons.volunteer_activism,
                    color: prayer.isAnswered ? AppTheme.emerald : AppTheme.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    prayer.title,
                    style: const TextStyle(fontFamily: 'Lora', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              if (prayer.isAnswered)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('ANSWERED 🎉', style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            prayer.content,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Prayed ${prayer.timesPrayed}×',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.gold),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(prayerRepositoryProvider).recordPrayer(prayer.id);
                  ref.read(prayerListProvider.notifier).load();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Prayer recorded! Amen. 🙏')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold.withOpacity(0.15),
                  foregroundColor: AppTheme.gold,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                icon: const Icon(Icons.favorite, size: 14),
                label: const Text('Pray Now', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultPrayersList(BuildContext context) {
    final list = [
      {'title': 'Family Unity & Peace', 'desc': 'Praying for God’s guidance and warmth in our home.', 'count': 14, 'answered': false},
      {'title': 'Wisdom for Career', 'desc': 'Lord grant wisdom for upcoming project decisions.', 'count': 8, 'answered': false},
      {'title': 'Healing for Sarah', 'desc': 'Praise God! Complete healing reported by doctor.', 'count': 22, 'answered': true},
    ];

    return Column(
      children: list.map((p) {
        final isAnswered = p['answered'] as bool;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.navySurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isAnswered ? AppTheme.emerald.withOpacity(0.4) : Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(isAnswered ? Icons.check_circle : Icons.volunteer_activism, color: isAnswered ? AppTheme.emerald : AppTheme.gold, size: 20),
                      const SizedBox(width: 10),
                      Text(p['title'] as String, style: const TextStyle(fontFamily: 'Lora', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    ],
                  ),
                  if (isAnswered)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.emerald.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Text('ANSWERED 🎉', style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(p['desc'] as String, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Prayed ${p['count']}×', style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.gold)),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prayer recorded! Amen. 🙏')));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold.withOpacity(0.15),
                      foregroundColor: AppTheme.gold,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: const Icon(Icons.favorite, size: 14),
                    label: const Text('Pray Now', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
