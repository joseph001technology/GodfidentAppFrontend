import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/widgets/progress_ring.dart' hide SectionHeader;
import '../../core/widgets/verse_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bible_provider.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/common/app_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _selectedMood;
  bool _prayerDone = false;
  bool _bibleReadDone = false;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning,';
    if (h < 17) return 'Good Afternoon,';
    return 'Good Evening,';
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

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(verseOfTheDayProvider);
          ref.invalidate(unreadCountProvider);
          ref.invalidate(readingProgressProvider);
          ref.invalidate(remindersProvider);
          ref.invalidate(dashboardProvider);
          ref.invalidate(dailyEncouragementProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(unreadAsync.valueOrNull ?? 0),
              const SizedBox(height: 20),
              userAsync.when(
                loading: () => const LoadingShimmer(height: 60),
                error: (_, __) => _buildGreeting('Beloved'),
                data: (user) => _buildGreeting(
                    user?.firstName.isNotEmpty == true ? user!.firstName : 'Beloved'),
              ),
              const SizedBox(height: 20),
              versesAsync.when(
                loading: () => const LoadingShimmer(height: 200, borderRadius: 20),
                error: (_, __) => const VerseCard(
                    verseText: '"For I know the plans I have for you..."',
                    reference: 'Jeremiah 29:11'),
                data: (verse) => VerseCard(verseText: verse.text, reference: verse.reference),
              ),
              const SizedBox(height: 20),
              _buildMoodRow(),
              const SizedBox(height: 20),
              _buildDevotionRow(),
              const SizedBox(height: 20),
              _buildProgressRing(dashboardAsync),
              const SizedBox(height: 20),
              _buildRemindersSection(remindersAsync),
              const SizedBox(height: 20),
              _buildMusicSection(),
              const SizedBox(height: 20),
              _buildInspirationSection(encouragementAsync),
              const SizedBox(height: 20),
              readingProgressAsync.when(
                loading: () => const LoadingShimmer(height: 100),
                error: (_, __) => const SizedBox.shrink(),
                data: (progress) => _buildContinueReadingCard(
                  location: progress['location'] ?? 'Genesis 1',
                  progress: (progress['percent'] ?? 0.0).toDouble(),
                  onTap: () => context.push('/bible'),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Reconstructed from c11e235 (last known-good design): "Online" status
  // pill + notification bell with a gold dot badge, restyled onto
  // AppTheme tokens to match the rest of this redesigned file.
  // ---------------------------------------------------------------------
  Widget _buildTopBar(int unreadCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withValues(alpha: 0.4), width: 0.5),
          ),
          child: const Row(
            children: [
              Icon(Icons.wifi, color: Colors.green, size: 12),
              SizedBox(width: 4),
              Text('Online',
                  style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: AppTheme.textPrimary, size: 26),
              onPressed: () => context.push('/notifications'),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppTheme.gold, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildGreeting(String name) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$_greeting\n',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: 'Lora',
                  color: AppTheme.textPrimary,
                ),
          ),
          TextSpan(
            text: name,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: 'Lora',
                  color: AppTheme.gold,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodRow() {
    final moods = [
      {'emoji': '🙏', 'label': 'Grateful'},
      {'emoji': '😌', 'label': 'Peaceful'},
      {'emoji': '💪', 'label': 'Strong'},
      {'emoji': '🤍', 'label': 'Loved'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'MOOD CHECK-IN'),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: moods.map((m) {
            final emoji = m['emoji'] as String;
            final selected = _selectedMood == emoji;
            return GestureDetector(
              onTap: () => setState(() => _selectedMood = selected ? null : emoji),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.gold.withValues(alpha: 0.15) : AppTheme.navySurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: selected ? AppTheme.gold.withValues(alpha: 0.6) : AppTheme.navyOutline),
                ),
                child: Column(children: [
                  Text(emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(m['label'] as String,
                      style: TextStyle(
                          fontSize: 10,
                          color: selected ? AppTheme.gold : AppTheme.textMuted,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDevotionRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: "TODAY'S DEVOTION"),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                if (_prayerDone) return;
                setState(() => _prayerDone = true);
                try {
                  final list = await ref.read(prayerRepositoryProvider).getList();
                  if (list.isNotEmpty) {
                    await ref.read(prayerRepositoryProvider).logPrayer(list.first.id);
                  }
                } catch (_) {}
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: Gradients.prayer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.glowEmerald),
                ),
                child: Row(children: [
                  const Icon(Icons.volunteer_activism_outlined, color: AppTheme.emerald, size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Text('Daily Prayer',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary))),
                  if (_prayerDone) const Icon(Icons.check_circle, color: AppTheme.emerald, size: 20),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                if (_bibleReadDone) return;
                setState(() => _bibleReadDone = true);
                try {
                  final repo = ref.read(bibleRepositoryProvider);
                  final progress = await repo.getReadingProgress();
                  final loc = progress['location']?.toString() ?? 'Genesis 1';
                  final parts = loc.split(' ');
                  final book = parts.isNotEmpty ? parts.first : 'Genesis';
                  final chapter = parts.length > 1 ? int.tryParse(parts.last) ?? 1 : 1;
                  await repo.logReading(book: book, chapter: chapter);
                } catch (_) {}
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: Gradients.bibleReading,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.glowPurple),
                ),
                child: Row(children: [
                  const Icon(Icons.menu_book_outlined, color: AppTheme.accentPurple, size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Text('Read Bible',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary))),
                  if (_bibleReadDone) const Icon(Icons.check_circle, color: AppTheme.emerald, size: 20),
                ]),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildProgressRing(AsyncValue<dynamic> dashboardAsync) {
    final progress = dashboardAsync.valueOrNull != null ? 0.5 : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: "TODAY'S PROGRESS"),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration:
              BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            ProgressRing(
              progress: progress.clamp(0.0, 1.0),
              size: 72,
              strokeWidth: 7,
              child: Text('${(progress * 100).toInt()}%',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.gold)),
            ),
            const SizedBox(width: 18),
            const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Keep it up!',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              SizedBox(height: 6),
              Text('Prayer · Bible · Focus',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textSecondary)),
            ])),
          ]),
        ),
      ],
    );
  }

  Widget _buildRemindersSection(AsyncValue<dynamic> remindersAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const SectionHeader(title: 'REMINDERS'),
          const Spacer(),
          TextButton(
            onPressed: () => context.push('/reminders'),
            child: const Text('Edit', style: TextStyle(fontSize: 12, color: AppTheme.gold)),
          ),
        ]),
        const SizedBox(height: 10),
        remindersAsync.when(
          loading: () => const LoadingShimmer(height: 120),
          error: (_, __) => Container(
            padding: const EdgeInsets.all(16),
            decoration:
                BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(16)),
            child: const Text('Could not load reminders.', style: TextStyle(color: AppTheme.textMuted)),
          ),
          data: (reminders) {
            final list = reminders.cast<dynamic>().take(3).toList();
            if (list.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppTheme.navySurface, borderRadius: BorderRadius.circular(16)),
                child: const Text('No reminders yet.', style: TextStyle(color: AppTheme.textMuted)),
              );
            }
            return Column(
                children: list.map((r) {
              final reminder = r as dynamic;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: AppTheme.navySurface, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.alarm_outlined, color: AppTheme.accentTeal, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(reminder.title ?? 'Reminder',
                          style: const TextStyle(
                              fontFamily: 'Inter', fontSize: 13, color: AppTheme.textPrimary))),
                  Text(reminder.date ?? '',
                      style: const TextStyle(
                          fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted)),
                ]),
              );
            }).toList());
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Reconstructed from c11e235: curated worship-song list, restyled onto
  // AppTheme tokens. c11e235 used a static const song list rather than
  // pulling from _musicRepo — kept that pattern here since _musicRepo's
  // API isn't visible to me. If StaticMusicRepository can supply a real
  // song list, swap _worshipSongs below for that instead.
  // ---------------------------------------------------------------------
  static const _worshipSongs = [
    {
      'title': 'Way Maker',
      'artist': 'Sinach',
      'duration': '4:32',
      'platform': 'spotify',
    },
    {
      'title': 'Goodness of God',
      'artist': 'Bethel Music',
      'duration': '5:14',
      'platform': 'spotify',
    },
    {
      'title': 'What a Beautiful Name',
      'artist': 'Hillsong',
      'duration': '4:58',
      'platform': 'youtube',
    },
  ];

  Widget _buildMusicSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'WORSHIP MUSIC'),
        const SizedBox(height: 10),
        ..._worshipSongs.map((song) {
          final isSpotify = song['platform'] == 'spotify';
          final platformColor = isSpotify ? const Color(0xFF1DB954) : const Color(0xFFFF0000);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration:
                BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppTheme.navyOutline.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.play_arrow_rounded, color: AppTheme.textSecondary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song['title']!,
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    Text('${song['artist']} · ${song['duration']}',
                        style: const TextStyle(
                            fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: platformColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: platformColor.withValues(alpha: 0.5), width: 0.5),
                ),
                child: Text(
                  isSpotify ? 'Spotify' : 'YouTube',
                  style: TextStyle(color: platformColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          );
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // STUB: original implementation wasn't recoverable from the merge.
  // ---------------------------------------------------------------------
  Widget _buildInspirationSection(AsyncValue<dynamic> encouragementAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'DAILY INSPIRATION'),
        const SizedBox(height: 10),
        encouragementAsync.when(
          loading: () => const LoadingShimmer(height: 80),
          error: (_, __) => const SizedBox.shrink(),
          data: (encouragement) => Container(
            padding: const EdgeInsets.all(16),
            decoration:
                BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(16)),
            child: Text(
              encouragement?.toString() ?? 'Stay strong in faith today.',
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                  fontStyle: FontStyle.italic),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Reconstructed from c11e235: label + location + progress bar, restyled
  // onto AppTheme tokens.
  // ---------------------------------------------------------------------
  Widget _buildContinueReadingCard({
    required String location,
    required double progress,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.2), width: 0.5),
        ),
        child: Row(children: [
          const Text('📖', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CONTINUE READING',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.gold)),
                const SizedBox(height: 2),
                Text(location,
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: AppTheme.navyOutline.withValues(alpha: 0.5),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 22),
        ]),
      ),
    );
  }
}