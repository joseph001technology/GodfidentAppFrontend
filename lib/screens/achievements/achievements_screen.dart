import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/achievements_provider.dart';
import '../../widgets/common/app_widgets.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsAsync = ref.watch(userAchievementsProvider);
    return Scaffold(
      body: RefreshIndicator(onRefresh: () async => ref.invalidate(userAchievementsProvider),
        child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Achievements', style: TextStyle(fontFamily: 'Lora', fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            achievementsAsync.when(loading: () => const _BadgesLoading(),
              error: (_, __) => const ErrorView(message: 'Could not load achievements'),
              data: (badges) => badges.isEmpty ? Center(child: Padding(padding: EdgeInsets.all(32),
                child: Text('Complete activities to earn achievements!', style: TextStyle(color: AppTheme.textMuted))))
                : GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.9, crossAxisSpacing: 10, mainAxisSpacing: 10),
                    itemCount: badges.length,
                    itemBuilder: (_, i) => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.navyOutline)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(badges[i].achievement.icon, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 6),
                        Text(badges[i].achievement.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      ]),
                    ),
                  ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BadgesLoading extends StatelessWidget {
  const _BadgesLoading();
  @override
  Widget build(BuildContext context) {
    return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.9, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: 6, itemBuilder: (_, i) => const LoadingShimmer(height: 100),
    );
  }
}
