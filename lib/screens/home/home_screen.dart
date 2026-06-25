import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/common/app_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final todayAsync = ref.watch(todayDevotionalProvider);
    final dashAsync  = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Godfident'),
        actions: [
          Consumer(builder: (_, ref, __) {
            final count = ref.watch(unreadCountProvider);
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => context.push('/more/notifications'),
                ),
                if (count.value != null && count.value! > 0)
                  Positioned(
                    right: 8, top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text('${count.value}', style: const TextStyle(color: Colors.white, fontSize: 9)),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.gold,
        onRefresh: () async {
          ref.invalidate(todayDevotionalProvider);
          ref.invalidate(dashboardProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Greeting
            userAsync.when(
              data: (user) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_greeting()},', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                  Text(
                    user?.displayName.split(' ').first ?? 'Friend',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ],
              ),
              loading: () => const LoadingShimmer(height: 52),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 20),

            // Streak + Quick stats
            dashAsync.when(
              data: (dash) => _StatsRow(dash: dash),
              loading: () => const LoadingShimmer(height: 80),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 20),

            // Today's Devotional
            SectionHeader(
              title: "TODAY'S DEVOTIONAL",
              trailing: TextButton(
                onPressed: () => context.push('/more/devotionals'),
                child: const Text('All'),
              ),
            ),
            todayAsync.when(
              data: (d) => _DevotionalCard(
                title: d.title,
                scripture: d.scriptureReference,
                onTap: () => context.push('/more/devotionals/${d.id}'),
              ),
              loading: () => const LoadingShimmer(height: 120),
              error: (_, __) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No devotional today.', style: Theme.of(context).textTheme.bodyMedium),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Daily Encouragement button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.gold,
                side: const BorderSide(color: AppTheme.gold, width: 0.5),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Daily Encouragement'),
              onPressed: () => _showEncouragement(context, ref),
            ),
            const SizedBox(height: 16),

            // Quick actions
            SectionHeader(title: 'QUICK ACCESS'),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _QuickTile(icon: Icons.menu_book, label: 'Read Bible', onTap: () => context.go('/bible')),
                _QuickTile(icon: Icons.volunteer_activism, label: 'Prayer', onTap: () => context.go('/prayer')),
                _QuickTile(icon: Icons.auto_awesome, label: 'AI Study', onTap: () => context.go('/ai')),
                _QuickTile(icon: Icons.list_alt, label: 'Plans', onTap: () => context.push('/more/plans')),
                _QuickTile(icon: Icons.bar_chart, label: 'Analytics', onTap: () => context.push('/more/analytics')),
                _QuickTile(icon: Icons.bookmark_outline, label: 'My Plans', onTap: () => context.push('/more/my-plans')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEncouragement(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.navySurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Consumer(
          builder: (_, ref, __) {
            final enc = ref.watch(dailyEncouragementProvider);
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text('Daily Encouragement', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.gold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: enc.when(
                      data: (text) => Markdown(data: text, styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))),
                      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.gold)),
                      error: (_, __) => const Text('Could not load encouragement.'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final dynamic dash;
  const _StatsRow({required this.dash});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
          icon: Icons.local_fire_department,
          value: '${dash.reading.currentStreak}',
          label: 'day streak',
          color: Colors.orange,
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.menu_book,
          value: '${dash.reading.chaptersThisWeek}',
          label: 'chapters',
          color: AppTheme.gold,
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.volunteer_activism,
          value: '${dash.prayer.totalPrayers}',
          label: 'prayers',
          color: Colors.pinkAccent,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.navyOutline, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _DevotionalCard extends StatelessWidget {
  final String title;
  final String scripture;
  final VoidCallback onTap;
  const _DevotionalCard({required this.title, required this.scripture, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(scripture, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.gold)),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Text('Read today\'s devotional', style: TextStyle(color: AppTheme.gold, fontSize: 12)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14, color: AppTheme.gold),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.gold, size: 26),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
