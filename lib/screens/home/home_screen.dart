import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/widgets/progress_ring.dart' hide SectionHeader;
import '../../core/widgets/verse_card.dart';
import '../../models/analytics.dart';
import '../../models/note.dart';
import '../../models/reminder.dart';
import '../../models/rule.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bible_provider.dart';
import '../../providers/notes_provider.dart';
import '../../providers/remaining_providers.dart';
import '../../providers/rules_provider.dart';
import '../../widgets/common/app_widgets.dart';
import '../../shared/widgets/premium_card.dart' as sh;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _selectedMood;
  bool _dailyPrayerCompleted = false;
  bool _readBibleCompleted = false;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning,';
    if (h < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  String get _motivationalMessage {
    final h = DateTime.now().hour;
    if (h < 6) return 'The Lord watches over you through the night.';
    if (h < 12) return 'This is the day the Lord has made.';
    if (h < 17) return 'May your heart find peace in His presence.';
    return 'Let the evening bring you closer to God.';
  }

  double get _devotionProgress {
    int done = 0;
    if (_dailyPrayerCompleted) done++;
    if (_readBibleCompleted) done++;
    return done / 2.0;
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final versesAsync = ref.watch(verseOfTheDayProvider);
    final unreadAsync = ref.watch(unreadCountProvider);
    final readingProgressAsync = ref.watch(readingProgressProvider);
    final remindersAsync = ref.watch(remindersProvider);
    final dashboardAsync = ref.watch(dashboardProvider);
    final encouragementAsync = ref.watch(dailyEncouragementProvider);
    final notesAsync = ref.watch(notesProvider);
    final todayRulesAsync = ref.watch(todayRulesProvider);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(verseOfTheDayProvider);
          ref.invalidate(unreadCountProvider);
          ref.invalidate(readingProgressProvider);
          ref.invalidate(remindersProvider);
          ref.invalidate(dashboardProvider);
          ref.invalidate(dailyEncouragementProvider);
          ref.invalidate(currentUserProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroHeader(userAsync, unreadAsync),
                    versesAsync.when(
                      loading: () => const LoadingShimmer(height: 180, borderRadius: 20),
                      error: (_, __) => const VerseCard(
                        verseText: '"I can do all things through Christ who strengthens me."',
                        reference: 'Philippians 4:13',
                      ),
                      data: (verse) => VerseCard(
                        verseText: verse.text,
                        reference: verse.reference,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildMoodTracker(),
                    const SizedBox(height: 20),
                    _buildTodayDevotionSection(dashboardAsync),
                    const SizedBox(height: 20),
                    _buildTodayProgressSection(dashboardAsync),
                    const SizedBox(height: 20),
                    _buildQuickActions(),
                    const SizedBox(height: 20),
                    _buildRemindersSection(remindersAsync),
                    const SizedBox(height: 20),
                    _buildWorshipMusicSection(),
                    const SizedBox(height: 20),
                    _buildDailyInspiration(),
                    const SizedBox(height: 20),
                    _buildContinueReading(readingProgressAsync),
                    const SizedBox(height: 20),
                    _buildRecentNotes(notesAsync),
                    const SizedBox(height: 20),
                    _buildUniversalRulesPreview(todayRulesAsync),
                    const SizedBox(height: 20),
                    _buildDailyInspirationQuote(encouragementAsync),
                    const SizedBox(height: 20),
                    _buildFocusCard(),
                    const SizedBox(height: 20),
                    _buildWeeklyPreview(dashboardAsync),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(AsyncValue<User?> userAsync, AsyncValue<int> unreadAsync) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0A1A), Color(0xFF14142A), Color(0xFF1A1040)],
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
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Online',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: AppTheme.textPrimary, size: 26),
                    onPressed: () => context.push('/more/notifications'),
                  ),
                  unreadAsync.when(
                    data: (count) => count > 0
                        ? Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppTheme.gold,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: AppTheme.navy,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          userAsync.when(
            loading: () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 18,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Text(
                  'Walk With God Today',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            error: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 18,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Text(
                  'Walk With God Today',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            data: (user) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 18,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  user?.firstName.isNotEmpty == true ? '${user!.firstName}, Walk With God' : 'Walk With God Today',
                  style: const TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _motivationalMessage,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodTracker() {
    final moods = [
      {'emoji': '😊', 'label': 'Joyful', 'color': const Color(0xFFFFD700)},
      {'emoji': '🙏', 'label': 'Peaceful', 'color': const Color(0xFF60A5FA)},
      {'emoji': '💪', 'label': 'Hopeful', 'color': const Color(0xFF10B981)},
      {'emoji': '😟', 'label': 'Low', 'color': const Color(0xFFF59E0B)},
      {'emoji': '🔥', 'label': 'On Fire', 'color': const Color(0xFFEF4444)},
    ];

    return sh.PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How are you feeling?',
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Your spiritual mood today',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: moods.map((m) {
              final label = m['label'] as String;
              final isSelected = _selectedMood == label;
              final color = m['color'] as Color;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedMood = isSelected ? null : label;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Spiritual mood updated: $label'),
                      duration: const Duration(seconds: 1),
                      backgroundColor: AppTheme.navySurface,
                    ),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.2) : AppTheme.navyVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? color : Colors.white.withOpacity(0.08),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        m['emoji'] as String,
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? color : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayDevotionSection(AsyncValue<Dashboard> dashboardAsync) {
    final streak = dashboardAsync.when(
      data: (d) => d.reading.currentStreak,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Devotion",
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  "Your daily spiritual checklist",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _dailyPrayerCompleted = !_dailyPrayerCompleted);
                  context.push('/prayer');
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF14142A), Color(0xFF1E1E3A)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _dailyPrayerCompleted
                          ? AppTheme.emerald
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.volunteer_activism, color: AppTheme.gold, size: 28),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _dailyPrayerCompleted ? AppTheme.emerald : Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              size: 14,
                              color: _dailyPrayerCompleted ? Colors.white : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Daily Prayer',
                        style: TextStyle(
                          fontFamily: 'Lora',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dailyPrayerCompleted ? 'Done! +1 streak' : 'Tap to pray',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: _dailyPrayerCompleted ? AppTheme.emerald : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _readBibleCompleted = !_readBibleCompleted);
                  context.push('/bible');
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF14142A), Color(0xFF1E1E3A)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _readBibleCompleted
                          ? AppTheme.gold
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.menu_book, color: AppTheme.softBlue, size: 28),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _readBibleCompleted ? AppTheme.gold : Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              size: 14,
                              color: _readBibleCompleted ? AppTheme.navy : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Read Bible',
                        style: TextStyle(
                          fontFamily: 'Lora',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _readBibleCompleted ? 'Done! +1 streak' : 'Tap to read',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: _readBibleCompleted ? AppTheme.gold : AppTheme.textMuted,
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

  Widget _buildTodayProgressSection(AsyncValue<Dashboard> dashboardAsync) {
    final prog = _devotionProgress;
    final pct = (prog * 100).toInt();

    final streak7 = dashboardAsync.when(
      data: (d) => d.reading.currentStreak,
      loading: () => 7,
      error: (_, __) => 7,
    );

    return sh.PremiumCard(
      padding: const EdgeInsets.all(20),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF14142A), Color(0xFF1A1040)],
      ),
      child: Row(
        children: [
          ProgressRing(
            progress: prog,
            size: 70,
            strokeWidth: 6,
            color: AppTheme.emerald,
            child: Text(
              '$pct%',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Progress",
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pct == 100 ? "🎉 Completed! Praise God!" : "Start your devotion",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: pct == 100 ? AppTheme.emerald : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('🔥 ', style: TextStyle(fontSize: 14)),
                    Text('${streak7}d', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.gold)),
                    const SizedBox(width: 12),
                    const Text('📖 ', style: TextStyle(fontSize: 14)),
                    const Text('14d', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.softBlue)),
                    const SizedBox(width: 12),
                    const Text('🎯 ', style: TextStyle(fontSize: 14)),
                    const Text('82%', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'icon': Icons.volunteer_activism, 'label': 'Pray', 'color': AppTheme.emerald, 'route': '/prayer/new'},
      {'icon': Icons.edit_note, 'label': 'Note', 'color': AppTheme.softBlue, 'route': '/notes/new'},
      {'icon': Icons.notifications, 'label': 'Reminder', 'color': AppTheme.gold, 'route': '/reminders/new'},
      {'icon': Icons.rule, 'label': 'Rule', 'color': AppTheme.accentPurple, 'route': '/rules/new'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontFamily: 'Lora',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: actions.map((act) {
            final color = act['color'] as Color;
            return Expanded(
              child: GestureDetector(
                onTap: () => context.push(act['route'] as String),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.25)),
                  ),
                  child: Column(
                    children: [
                      Icon(act['icon'] as IconData, color: color, size: 24),
                      const SizedBox(height: 6),
                      Text(
                        act['label'] as String,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRemindersSection(AsyncValue<List<Reminder>> remindersAsync) {
    return sh.PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reminders',
                style: TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/reminders'),
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          remindersAsync.when(
            loading: () => const LoadingShimmer(height: 80),
            error: (_, __) => _buildDefaultRemindersList(),
            data: (reminders) {
              if (reminders.isEmpty) return _buildDefaultRemindersList();
              return Column(
                children: reminders.take(3).map((r) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.navyVariant,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active_outlined, color: AppTheme.gold, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.title,
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                ),
                                Text(
                                  r.formattedTime.isNotEmpty ? r.formattedTime : 'Daily reminder',
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: r.isActive,
                            onChanged: (val) {},
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultRemindersList() {
    final list = [
      {'title': 'Morning Prayer', 'time': '6:00 AM · Start your day with God', 'icon': Icons.wb_sunny_outlined, 'enabled': true},
      {'title': 'Read Scripture', 'time': '7:00 AM · Daily Bible reading', 'icon': Icons.menu_book, 'enabled': true},
      {'title': 'Midday Prayer', 'time': '12:00 PM · Pause and pray', 'icon': Icons.wb_twilight, 'enabled': false},
    ];

    return Column(
      children: list.map((item) {
        final isEnabled = item['enabled'] as bool;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.navyVariant,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(item['icon'] as IconData, color: AppTheme.gold, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] as String,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    Text(
                      item['time'] as String,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: (v) {},
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWorshipMusicSection() {
    final tracks = [
      {'title': 'Way Maker', 'artist': 'Sinach · 4:32', 'badge': 'Spotify', 'badgeColor': const Color(0xFF1DB954)},
      {'title': 'Goodness of God', 'artist': 'Bethel Music · 5:14', 'badge': 'Spotify', 'badgeColor': const Color(0xFF1DB954)},
      {'title': 'What a Beautiful Name', 'artist': 'Hillsong · 4:58', 'badge': 'YouTube', 'badgeColor': const Color(0xFFFF0000)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Worship Music',
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Lift your spirit',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const Text(
              'See all',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppTheme.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...tracks.map((t) {
          final bColor = t['badgeColor'] as Color;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.navySurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['title'] as String,
                        style: const TextStyle(fontFamily: 'Lora', fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      Text(
                        t['artist'] as String,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: bColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    t['badge'] as String,
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: bColor),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDailyInspiration() {
    final scenes = [
      {'title': 'Rise With Purpose', 'gradient': [const Color(0xFFD97706), const Color(0xFF78350F)], 'icon': Icons.wb_sunny},
      {'title': 'Worship in Spirit', 'gradient': [const Color(0xFF4F46E5), const Color(0xFF312E81)], 'icon': Icons.volunteer_activism},
      {'title': 'His Creation Speaks', 'gradient': [const Color(0xFF059669), const Color(0xFF064E3B)], 'icon': Icons.eco},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Inspiration',
          style: TextStyle(
            fontFamily: 'Lora',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          'Scenes of faith',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: scenes.length,
            itemBuilder: (context, idx) {
              final sc = scenes[idx];
              final colors = sc['gradient'] as List<Color>;
              return Container(
                width: 125,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(sc['icon'] as IconData, color: Colors.white, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      sc['title'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContinueReading(AsyncValue<Map<String, dynamic>> progressAsync) {
    return sh.PremiumCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF14142A), Color(0xFF1E1E3A)],
      ),
      onTap: () => context.push('/bible'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Continue Reading',
                style: TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.gold,
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: AppTheme.gold, size: 14),
            ],
          ),
          const SizedBox(height: 10),
          progressAsync.when(
            loading: () => const LoadingShimmer(height: 30),
            error: (_, __) => const Text(
              'Psalm 23 — Verse 4',
              style: TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            data: (progress) {
              final loc = progress['location'] ?? 'Psalm 23 — Verse 4';
              final percent = (progress['percent'] ?? 0.65).toDouble();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.toString(),
                    style: const TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDailyInspirationQuote(AsyncValue<dynamic> encouragementAsync) {
    return sh.PremiumCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A3A2A), Color(0xFF0D2618)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨ ', style: TextStyle(fontSize: 16)),
              Text(
                'DAILY MOTIVATION',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.gold.withOpacity(0.9),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          encouragementAsync.when(
            loading: () => const LoadingShimmer(height: 30),
            error: (_, __) => const Text(
              '"Trust in the LORD with all your heart and lean not on your own understanding." — Proverbs 3:5',
              style: TextStyle(fontFamily: 'Lora', fontSize: 14, fontStyle: FontStyle.italic, color: AppTheme.textPrimary, height: 1.5),
            ),
            data: (txt) => Text(
              txt?.toString() ?? '"Trust in the LORD with all your heart and lean not on your own understanding." — Proverbs 3:5',
              style: const TextStyle(fontFamily: 'Lora', fontSize: 14, fontStyle: FontStyle.italic, color: AppTheme.textPrimary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusCard() {
    return sh.PremiumCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A1A4A), Color(0xFF2D1B69)],
      ),
      onTap: () => context.push('/focus'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.track_changes, color: AppTheme.gold, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'DIGITAL FOCUS',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.gold.withOpacity(0.9),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Protect your attention.\nHonor God with your time.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.shield_outlined, color: AppTheme.gold, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyPreview(AsyncValue<Dashboard> dashboardAsync) {
    final readingChapters = dashboardAsync.when(
      data: (d) => d.reading.chaptersThisWeek,
      loading: () => 12,
      error: (_, __) => 12,
    );

    final totalPrayers = dashboardAsync.when(
      data: (d) => d.prayer.totalPrayers,
      loading: () => 28,
      error: (_, __) => 28,
    );

    final streak = dashboardAsync.when(
      data: (d) => d.reading.currentStreak,
      loading: () => 7,
      error: (_, __) => 7,
    );

    return sh.PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Summary',
                style: TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/analytics'),
                child: const Text(
                  'Analytics →',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeekStat('📖', '$readingChapters', 'Chapters'),
              _buildWeekStat('🙏', '$totalPrayers', 'Prayers'),
              _buildWeekStat('🔥', '${streak}d', 'Streak'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        Text(
          label,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _buildRecentNotes(AsyncValue<List<Note>> notesAsync) {
    return sh.PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Recent Notes', style: TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            GestureDetector(onTap: () => context.push('/notes'), child: const Text('View All →', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.gold, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 14),
          notesAsync.when(loading: () => const LoadingShimmer(height: 80), error: (_, __) => _buildDefaultRecentNotes(), data: (notes) {
            final recent = notes.take(3).toList();
            if (recent.isEmpty) return _buildDefaultRecentNotes();
            return Column(children: recent.map((n) {
              final topic = n.topicName.isNotEmpty ? n.topicName : 'General';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: AppTheme.navyVariant, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppTheme.softBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(topic, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.softBlue))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                  if (n.isPinned) const Icon(Icons.push_pin, color: AppTheme.gold, size: 14),
                ]),
              );
            }).toList());
          }),
        ],
      ),
    );
  }

  Widget _buildDefaultRecentNotes() {
    final notes = [
      {'title': 'Walking in Divine Grace', 'topic': 'Grace', 'pinned': true},
      {'title': 'Kingdom Leadership Principles', 'topic': 'Leadership', 'pinned': false},
      {'title': 'Faith in Times of Trial', 'topic': 'Faith', 'pinned': false},
    ];
    return Column(children: notes.map((n) {
      final isPinned = n['pinned'] as bool;
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppTheme.navyVariant, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppTheme.softBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text(n['topic'] as String, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.softBlue))),
          const SizedBox(width: 10),
          Expanded(child: Text(n['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
          if (isPinned) const Icon(Icons.push_pin, color: AppTheme.gold, size: 14),
        ]),
      );
    }).toList());
  }

  Widget _buildUniversalRulesPreview(AsyncValue<List<Rule>> rulesAsync) {
    return sh.PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Universal Rules', style: TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            GestureDetector(onTap: () => context.push('/rules'), child: const Text('View All →', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.gold, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 6),
          Text('Live by your God-given rules today', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 14),
          rulesAsync.when(
            loading: () => const LoadingShimmer(height: 80),
            error: (_, __) => _buildDefaultRulesList(),
            data: (rules) {
              final todayRules = rules.where((r) => !r.isCompleted).take(3).toList();
              if (todayRules.isEmpty) return _buildDefaultRulesList();
              return Column(children: todayRules.map((r) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: AppTheme.navyVariant, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.gold, width: 1.5)), child: r.isCompleted ? Icon(Icons.check, size: 14, color: AppTheme.gold) : null),
                      const SizedBox(width: 12),
                      Expanded(child: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, decoration: r.isCompleted ? TextDecoration.lineThrough : null))),
                      if (r.isPinned) Icon(Icons.push_pin, color: AppTheme.gold.withOpacity(0.8), size: 14),
                    ]),
                  ),
                );
              }).toList());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultRulesList() {
    final rules = [
      {'title': 'Start the day with prayer', 'pinned': true, 'done': false},
      {'title': 'Read at least one chapter', 'pinned': false, 'done': true},
      {'title': 'Speak life, not criticism', 'pinned': false, 'done': false},
    ];
    return Column(children: rules.map((r) {
      final isPinned = r['pinned'] as bool;
      final isDone = r['done'] as bool;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppTheme.navyVariant, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.gold, width: 1.5)), child: isDone ? Icon(Icons.check, size: 14, color: AppTheme.gold) : null),
            const SizedBox(width: 12),
            Expanded(child: Text(r['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, decoration: isDone ? TextDecoration.lineThrough : null))),
            if (isPinned) Icon(Icons.push_pin, color: AppTheme.gold, size: 14),
          ]),
        ),
      );
    }).toList());
  }
}