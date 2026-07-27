import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/design_utils.dart';
import '../../widgets/premium_components.dart';

// ══════════════════════════════════════════════════════════════════════════
// NEW HOME DASHBOARD - SPIRITUAL GROWTH COMPANION
// ══════════════════════════════════════════════════════════════════════════

class HomeScreenRedesigned extends ConsumerStatefulWidget {
  const HomeScreenRedesigned({super.key});

  @override
  ConsumerState<HomeScreenRedesigned> createState() => _HomeScreenRedesignedState();
}

class _HomeScreenRedesignedState extends ConsumerState<HomeScreenRedesigned> {
  late PageController _pageController;
  int _selectedMood = -1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = _getGreeting(hour);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: CustomScrollView(
        slivers: [
          // ────────────────────────────────────────────────────────────
          // HEADER WITH GREETING & STATUS
          // ────────────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppTheme.navy,
            elevation: 0,
            expandedHeight: 0,
            toolbarHeight: 70,
            title: _buildHeaderGretting(greeting, hour),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: DesignUtils.spacingLg),
                child: Center(
                  child: Text(
                    'Online',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.emerald,
                        ),
                  ),
                ),
              ),
            ],
          ),

          // ────────────────────────────────────────────────────────────
          // MAIN CONTENT
          // ────────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(DesignUtils.spacingLg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // TODAY'S VERSE CARD
                _buildVerseOfTheDay(context),
                const SizedBox(height: DesignUtils.spacingXl),

                // HOW ARE YOU FEELING?
                _buildMoodTracker(context),
                const SizedBox(height: DesignUtils.spacingXl),

                // TODAY'S DEVOTION (Quick Actions)
                _buildTodaysDevotionCard(context),
                const SizedBox(height: DesignUtils.spacingXl),

                // TODAY'S PROGRESS
                _buildTodaysProgress(context),
                const SizedBox(height: DesignUtils.spacingXl),

                // REMINDERS
                _buildRemindersSection(context),
                const SizedBox(height: DesignUtils.spacingXl),

                // CONTINUE READING
                _buildContinueReadingCard(context),
                const SizedBox(height: DesignUtils.spacingXl),

                // WORSHIP MUSIC
                _buildWorshipMusic(context),
                const SizedBox(height: DesignUtils.spacingXl),

                // DAILY INSPIRATION
                _buildDailyInspiration(context),
                const SizedBox(height: DesignUtils.spacingXl),

                // UNIVERSAL RULES PREVIEW
                _buildRulesPreview(context),
                const SizedBox(height: DesignUtils.spacingHuge),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // HEADER WITH GREETING
  // ──────────────────────────────────────────────────────────────────────

  Widget _buildHeaderGretting(String greeting, int hour) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$greeting,',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        Text(
          'Walk With God Today',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
            ),
        ),
      ],
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // VERSE OF THE DAY CARD
  // ──────────────────────────────────────────────────────────────────────

  Widget _buildVerseOfTheDay(BuildContext context) {
    return PremiumCard(
      gradient: DesignUtils.warmGradient,
      padding: const EdgeInsets.all(DesignUtils.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '✨ VERSE OF THE DAY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: DesignUtils.spacingMd),
          Text(
            '"I can do all things through Christ who strengthens me."',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: DesignUtils.spacingSm),
          Text(
            '— Philippians 4:13',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.gold,
                ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // MOOD TRACKER
  // ──────────────────────────────────────────────────────────────────────

  Widget _buildMoodTracker(BuildContext context) {
    const moods = [
      ('😊', 'Joyful'),
      ('🙏', 'Peaceful'),
      ('💪', 'Hopeful'),
      ('😔', 'Low'),
      ('🔥', 'On Fire'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How are you feeling?',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: DesignUtils.spacingSm),
        Text(
          'Your spiritual mood today',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        const SizedBox(height: DesignUtils.spacingMd),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            moods.length,
            (i) => GestureDetector(
              onTap: () => setState(() => _selectedMood = i),
              child: AnimatedScale(
                scale: _selectedMood == i ? 1.1 : 1.0,
                duration: DesignUtils.shortDuration,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _selectedMood == i
                        ? AppTheme.navyVariant
                        : AppTheme.navySurface,
                    border: Border.all(
                      color: _selectedMood == i
                          ? AppTheme.gold
                          : AppTheme.navyOutline,
                      width: _selectedMood == i ? 2 : 0.5,
                    ),
                    borderRadius: DesignUtils.mediumRadius,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(moods[i].$1, style: const TextStyle(fontSize: 24)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_selectedMood >= 0) ...[
          const SizedBox(height: DesignUtils.spacingSm),
          Text(
            'You\'re feeling ${moods[_selectedMood].$2}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.softBlue,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // TODAY'S DEVOTION (Quick Actions)
  // ──────────────────────────────────────────────────────────────────────

  Widget _buildTodaysDevotionCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Devotion',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: DesignUtils.spacingMd),
        Text(
          'Your daily spiritual checklist',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        const SizedBox(height: DesignUtils.spacingMd),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => context.push('/prayer/new'),
                child: PremiumCard(
                  padding: const EdgeInsets.all(DesignUtils.spacingLg),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppTheme.navySurface,
                          borderRadius: DesignUtils.mediumRadius,
                        ),
                        child: const Center(
                          child: Text('🙏', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                      const SizedBox(height: DesignUtils.spacingSm),
                      Text(
                        'Daily Prayer',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DesignUtils.spacingSm),
                      Text(
                        'Tap to pray',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: DesignUtils.spacingMd),
            Expanded(
              child: GestureDetector(
                onTap: () => context.push('/bible'),
                child: PremiumCard(
                  padding: const EdgeInsets.all(DesignUtils.spacingLg),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppTheme.navySurface,
                          borderRadius: DesignUtils.mediumRadius,
                        ),
                        child: const Center(
                          child: Text('📖', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                      const SizedBox(height: DesignUtils.spacingSm),
                      Text(
                        'Read Bible',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DesignUtils.spacingSm),
                      Text(
                        'Tap to read',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // TODAY'S PROGRESS
  // ──────────────────────────────────────────────────────────────────────

  Widget _buildTodaysProgress(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(DesignUtils.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Progress',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '0%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: DesignUtils.spacingSm),
          Text(
            'Start your devotion',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: DesignUtils.spacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildProgressItem(context, '🔥', '7d', 'Prayer Streak'),
              _buildProgressItem(context, '📖', '14d', 'Reading Streak'),
              _buildProgressItem(context, '🎯', '82%', 'Focus Score'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(BuildContext context, String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: DesignUtils.spacingSm),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: DesignUtils.spacingXs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey,
              ),
        ),
      ],
    );
  }

  // Placeholder methods - implement based on actual data
  Widget _buildRemindersSection(BuildContext context) => const SizedBox.shrink();
  Widget _buildContinueReadingCard(BuildContext context) => const SizedBox.shrink();
  Widget _buildWorshipMusic(BuildContext context) => const SizedBox.shrink();
  Widget _buildDailyInspiration(BuildContext context) => const SizedBox.shrink();
  Widget _buildRulesPreview(BuildContext context) => const SizedBox.shrink();
}
