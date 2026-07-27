import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/focus_provider.dart';
import '../../widgets/common/app_widgets.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});
  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(focusStatsProvider);
    final blockedAppsAsync = ref.watch(blockedAppsProvider);
    final sessionAsync = ref.watch(activeSessionProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(focusStatsProvider);
          ref.invalidate(blockedAppsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(sessionAsync),
              const SizedBox(height: 20),
              _buildStats(statsAsync),
              const SizedBox(height: 20),
              _buildBlockedApps(blockedAppsAsync),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AsyncValue<dynamic> sessionAsync) {
    return Row(children: [
      const Text('Digital Focus', style: TextStyle(fontFamily: 'Lora', fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
      const Spacer(),
      sessionAsync.when(data: (session) {
        final isActive = session != null && session.isActive;
        return ElevatedButton(
          onPressed: () => isActive
            ? ref.read(activeSessionProvider.notifier).end()
            : ref.read(activeSessionProvider.notifier).start(),
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? AppTheme.accentPink : AppTheme.gold,
            minimumSize: const Size(120, 40),
          ),
          child: Text(isActive ? 'End Focus' : 'Start Focus', style: const TextStyle(fontSize: 12, color: AppTheme.navy)),
        );
      }, loading: () => const SizedBox(width: 120, height: 40, child: LoadingShimmer()),
        error: (_, __) => ElevatedButton(onPressed: () => ref.read(activeSessionProvider.notifier).start(),
          style: ElevatedButton.styleFrom(minimumSize: const Size(120, 40)), child: const Text('Start Focus', style: TextStyle(fontSize: 12)))),
    ]);
  }

  Widget _buildStats(AsyncValue<dynamic> statsAsync) {
    return statsAsync.when(
      loading: () => Row(children: const [Expanded(child: LoadingShimmer(height: 100)), SizedBox(width: 10), Expanded(child: LoadingShimmer(height: 100)), SizedBox(width: 10), Expanded(child: LoadingShimmer(height: 100))]),
      error: (_, __) => Row(children: [_StatCard(icon: '🎯', label: 'Focus Score', value: '--', color: AppTheme.gold),
        const SizedBox(width: 10), _StatCard(icon: '📱', label: 'Avg Screen', value: '--', color: AppTheme.accentPurple),
        const SizedBox(width: 10), _StatCard(icon: '⏱️', label: 'Time Saved', value: '--', color: AppTheme.emerald)]),
      data: (stats) => Row(children: [
        _StatCard(icon: '🎯', label: 'Focus Score', value: '${stats.averageFocusScore.toInt()}%', color: AppTheme.gold),
        const SizedBox(width: 10),
        _StatCard(icon: '📱', label: 'Avg Screen', value: '${stats.totalFocusMinutes ~/ 60}h ${stats.totalFocusMinutes % 60}m', color: AppTheme.accentPurple),
        const SizedBox(width: 10),
        _StatCard(icon: '⏱️', label: 'Time Saved', value: '${stats.timeSavedMinutes ~/ 60}h', color: AppTheme.emerald),
      ]),
    );
  }

  Widget _buildBlockedApps(AsyncValue<List<dynamic>> appsAsync) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        SectionHeader(title: 'BLOCKED APPS', trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppTheme.gold, size: 22), onPressed: () {
          final controller = TextEditingController();
          showDialog(context: context, builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.navySurface, title: const Text('Add Blocked App'),
            content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'App name', hintStyle: TextStyle(color: AppTheme.textMuted)), style: const TextStyle(color: AppTheme.textPrimary)),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(onPressed: () { if (controller.text.isNotEmpty) { ref.read(focusRepositoryProvider).addBlockedApp({'app_name': controller.text, 'package_name': ''}); ref.invalidate(blockedAppsProvider); Navigator.pop(ctx); } }, child: const Text('Add'))],
          ));
        })),
      ]),
      appsAsync.when(loading: () => const LoadingShimmer(height: 100),
        error: (_, __) => const SizedBox.shrink(),
        data: (apps) => apps.isEmpty ? Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(16)),
            child: const Text('No blocked apps yet.', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textMuted)))
            : ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                itemCount: apps.length,
                itemBuilder: (_, i) => Container(margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Icon(Icons.block, color: AppTheme.accentPink, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(apps[i].appName, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textPrimary))),
                  ]),
                ),
              ),
      ),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String icon, label, value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [color.withOpacity(0.1), AppTheme.navySurface]),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppTheme.textMuted)),
      ]),
    );
  }
}
