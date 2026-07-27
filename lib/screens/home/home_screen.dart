import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/verse_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bible_provider.dart';
import '../../providers/remaining_providers.dart';
import '../../services/music_repository.dart';
import '../../widgets/common/app_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int? _selectedMood;
  final _musicRepo = StaticMusicRepository();
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
              _TopBar(unreadCount: unreadAsync.valueOrNull ?? 0),
              const SizedBox(height: 20),
              userAsync.when(
                loading: () => const LoadingShimmer(height: 60),
                error: (_, __) => _buildGreeting('Beloved'),
                data: (user) => _buildGreeting(user?.firstName.isNotEmpty == true ? user!.firstName : 'Beloved'),
              ),
              const SizedBox(height: 20),
              versesAsync.when(
                loading: () => const LoadingShimmer(height: 200, borderRadius: 20),
                error: (_, __) => VerseCard(verseText: '"For I know the plans I have for you..."', reference: 'Jeremiah 29:11'),
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
                data: (progress) => _ContinueReadingCard(
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

  Widget _buildGreeting(String name) {
    return RichText(
      text: TextSpan(
        children: [

  Widget _buildMoodRow() {
    final moods = [{'emoji': '🙏', 'label': 'Grateful'}, {'emoji': '😌', 'label': 'Peaceful'}, {'emoji': '💪', 'label': 'Strong'}, {'emoji': '🤍', 'label': 'Loved'}];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'MOOD CHECK-IN'),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: moods.map((m) {
            final selected = _selectedMood == m['emoji'];
            return GestureDetector(
              onTap: () => setState(() => _selectedMood = _selectedMood == m['emoji'] ? null : m['emoji'] as int?),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.gold.withOpacity(0.15) : AppTheme.navySurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? AppTheme.gold.withOpacity(0.6) : AppTheme.navyOutline),
                ),
                child: Column(children: [
                  Text(m['emoji'] as String, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(m['label'] as String, style: TextStyle(fontSize: 10, color: selected ? AppTheme.gold : AppTheme.textMuted, fontWeight: FontWeight.w600)),
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
                  final list = await ref.read(prayerRepositoryProvider).getList(limit: 1);
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
                  Expanded(child: Text('Daily Prayer', style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
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
                  final repo = BibleRepository();
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
                  Expanded(child: Text('Read Bible', style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                  if (_bibleReadDone) const Icon(Icons.check_circle, color: AppTheme.emerald, size: 20),
                ]),
              ),
            ),
          ),
        ]),
      ],
    );
  }

          TextSpan(
            text: '$_greeting\n',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: 'Lora',
                  color: AppTheme.textPrimary,
                ),
          ),
          TextSpan(
            text: 'Walk With God Today',
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
