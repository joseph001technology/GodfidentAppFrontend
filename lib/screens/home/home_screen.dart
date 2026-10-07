import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/reminder.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bible_provider.dart';
import '../../providers/focus_provider.dart';
import '../../providers/remaining_providers.dart';
import '../../providers/rules_provider.dart';
import '../../models/rule.dart';
import '../../widgets/common/app_widgets.dart';

/// Home - deliberately simple (see the prototype): greeting, verse of the day,
/// two real stats, a Focus call-to-action, where you left off, and reminders.
/// Every value here comes from the backend; nothing is invented when a call
/// fails - the section shows an honest message instead.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final verse = ref.watch(verseOfTheDayProvider);
    final streak = ref.watch(readingStreakProvider);
    final focus = ref.watch(focusStatsProvider);
    final progress = ref.watch(readingProgressProvider);
    final reminders = ref.watch(remindersProvider);

    final first = (user?.firstName ?? '').trim();
    final initials = [user?.firstName, user?.lastName]
        .where((s) => s != null && s.isNotEmpty)
        .map((s) => s![0].toUpperCase())
        .join();

    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.gold,
          onRefresh: () async {
            ref.invalidate(verseOfTheDayProvider);
            ref.invalidate(readingStreakProvider);
            ref.invalidate(focusStatsProvider);
            ref.invalidate(readingProgressProvider);
            ref.invalidate(remindersProvider);
            ref.invalidate(currentUserProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // Header
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_greeting.toUpperCase(),
                        style: TextStyle(
                            fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                    const SizedBox(height: 2),
                    Text(first.isEmpty ? 'Welcome' : first,
                        style: TextStyle(
                            fontFamily: 'Lora', fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.ink)),
                  ]),
                ),
                IconButton(
                  onPressed: () => context.push('/global-search'),
                  icon: Icon(Icons.search, color: AppTheme.ink),
                ),
                GestureDetector(
                  onTap: () => context.go('/profile'),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.inkNavy,
                    child: Text(initials.isEmpty ? '·' : initials,
                        style: const TextStyle(color: AppTheme.goldLight, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              // Universal Rules rotate here every hour. Until some are added,
              // a verse is shown instead (it also changes through the day).
              _HourlyWordCard(card: _card),
              const SizedBox(height: 14),

              // Two real stats
              Row(children: [
                Expanded(
                  child: _stat(
                    Icons.local_fire_department_outlined,
                    streak.when(
                      data: (s) => '${s.currentStreak} day${s.currentStreak == 1 ? '' : 's'}',
                      loading: () => '…',
                      error: (_, __) => '–',
                    ),
                    'Reading streak',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _stat(
                    Icons.timer_outlined,
                    focus.when(
                      data: (f) => _minutes(f.totalFocusMinutes),
                      loading: () => '…',
                      error: (_, __) => '–',
                    ),
                    'Focused in total',
                  ),
                ),
              ]),
              const SizedBox(height: 14),

              // Focus call to action
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.go('/focus'),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: AppTheme.inkNavy, borderRadius: BorderRadius.circular(18)),
                  child: const Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Start a Focus session',
                            style: TextStyle(
                                fontFamily: 'Lora', fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textOnDark)),
                        SizedBox(height: 3),
                        Text('Block distracting apps and websites',
                            style: TextStyle(fontSize: 12, color: AppTheme.textOnDarkMuted)),
                      ]),
                    ),
                    Icon(Icons.arrow_forward, color: AppTheme.goldLight),
                  ]),
                ),
              ),

              // Continue reading - only when the server has real progress
              ...progress.maybeWhen(
                data: (p) {
                  final loc = p['location'];
                  if (loc == null) return <Widget>[];
                  final pct = ((p['percent'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);
                  return [
                    const SizedBox(height: 22),
                    _sectionTitle('Continue reading'),
                    const SizedBox(height: 10),
                    _card(
                      onTap: () => context.go('/bible'),
                      child: Row(children: [
                        const Icon(Icons.menu_book, color: AppTheme.goldDark),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('$loc', style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (pct > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 5,
                                  color: AppTheme.gold,
                                  backgroundColor: AppTheme.navyVariant,
                                ),
                              ),
                          ]),
                        ),
                        Icon(Icons.chevron_right, color: AppTheme.textMuted),
                      ]),
                    ),
                  ];
                },
                orElse: () => <Widget>[],
              ),

              // Reminders
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: _sectionTitle("Today's reminders")),
                TextButton(onPressed: () => context.go('/reminders'), child: const Text('See all')),
              ]),
              reminders.when(
                loading: () => const LoadingShimmer(height: 60),
                error: (e, _) => Text(friendlyError(e), style: TextStyle(color: AppTheme.textSecondary)),
                data: (list) {
                  final active = list.where((r) => r.isActive).take(3).toList();
                  if (active.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No reminders yet.', style: TextStyle(color: AppTheme.textSecondary)),
                    );
                  }
                  return Column(children: [for (final r in active) _reminderRow(r)]);
                },
              ),

              // Shortcuts to the two other core features
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: _shortcut(context, Icons.volunteer_activism_outlined, 'Prayer', '/prayer')),
                const SizedBox(width: 12),
                Expanded(child: _shortcut(context, Icons.edit_note, 'Notes', '/notes')),
                const SizedBox(width: 12),
                Expanded(child: _shortcut(context, Icons.library_music_outlined, 'Music', '/music')),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  static String _minutes(int m) => m < 60 ? '${m}m' : '${m ~/ 60}h ${m % 60}m';

  Widget _sectionTitle(String t) => Text(t,
      style: TextStyle(fontFamily: 'Lora', fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.ink));

  Widget _card({required Widget child, VoidCallback? onTap}) => InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.navySurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.navyOutline),
          ),
          child: child,
        ),
      );

  Widget _stat(IconData icon, String value, String label) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.navyOutline),
        ),
        child: Row(children: [
          Icon(icon, color: AppTheme.goldDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.ink)),
              Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ]),
          ),
        ]),
      );

  Widget _reminderRow(Reminder r) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.navyOutline),
        ),
        child: Row(children: [
          const Icon(Icons.circle, size: 8, color: AppTheme.gold),
          const SizedBox(width: 12),
          Expanded(child: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(r.formattedTime, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ]),
      );

  Widget _shortcut(BuildContext context, IconData icon, String label, String route) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.navySurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.navyOutline),
          ),
          child: Column(children: [
            Icon(icon, color: AppTheme.goldDark),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}


/// A short, well-known set of verses used when the person has not added any
/// Universal Rules yet. KJV (public domain), so it works offline too.
const _fallbackVerses = <(String text, String ref, String book, int chapter)>[
  ('The Lord is my shepherd; I shall not want.', 'Psalm 23:1', 'Psalms', 23),
  ('Trust in the Lord with all thine heart; and lean not unto thine own understanding.', 'Proverbs 3:5', 'Proverbs', 3),
  ('I can do all things through Christ which strengtheneth me.', 'Philippians 4:13', 'Philippians', 4),
  ('Be still, and know that I am God.', 'Psalm 46:10', 'Psalms', 46),
  ('The Lord is my light and my salvation; whom shall I fear?', 'Psalm 27:1', 'Psalms', 27),
  ('Casting all your care upon him; for he careth for you.', '1 Peter 5:7', '1 Peter', 5),
  ('Thy word is a lamp unto my feet, and a light unto my path.', 'Psalm 119:105', 'Psalms', 119),
  ('Come unto me, all ye that labour and are heavy laden, and I will give you rest.', 'Matthew 11:28', 'Matthew', 11),
  ('But they that wait upon the Lord shall renew their strength; they shall mount up with wings as eagles.', 'Isaiah 40:31', 'Isaiah', 40),
  ('Fear thou not; for I am with thee: be not dismayed; for I am thy God.', 'Isaiah 41:10', 'Isaiah', 41),
  ('Seek ye first the kingdom of God, and his righteousness; and all these things shall be added unto you.', 'Matthew 6:33', 'Matthew', 6),
  ('Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God.', 'Philippians 4:6', 'Philippians', 4),
  ('The Lord is nigh unto all them that call upon him, to all that call upon him in truth.', 'Psalm 145:18', 'Psalms', 145),
  ('Create in me a clean heart, O God; and renew a right spirit within me.', 'Psalm 51:10', 'Psalms', 51),
  ('And we know that all things work together for good to them that love God.', 'Romans 8:28', 'Romans', 8),
  ('Let your light so shine before men, that they may see your good works, and glorify your Father which is in heaven.', 'Matthew 5:16', 'Matthew', 5),
  ('Draw nigh to God, and he will draw nigh to you.', 'James 4:8', 'James', 4),
  ('The name of the Lord is a strong tower: the righteous runneth into it, and is safe.', 'Proverbs 18:10', 'Proverbs', 18),
  ('This is the day which the Lord hath made; we will rejoice and be glad in it.', 'Psalm 118:24', 'Psalms', 118),
  ('Peace I leave with you, my peace I give unto you: not as the world giveth, give I unto you.', 'John 14:27', 'John', 14),
  ('Rejoice in the Lord alway: and again I say, Rejoice.', 'Philippians 4:4', 'Philippians', 4),
  ('Pray without ceasing.', '1 Thessalonians 5:17', '1 Thessalonians', 5),
  ('Great is thy faithfulness.', 'Lamentations 3:23', 'Lamentations', 3),
  ('Thou wilt keep him in perfect peace, whose mind is stayed on thee: because he trusteth in thee.', 'Isaiah 26:3', 'Isaiah', 26),
];

/// Home card. With Universal Rules: one rule at a time, a new one every hour.
/// Without: the verse of the day first, then a new verse every hour.
class _HourlyWordCard extends ConsumerStatefulWidget {
  final Widget Function({required Widget child, VoidCallback? onTap}) card;
  const _HourlyWordCard({required this.card});

  @override
  ConsumerState<_HourlyWordCard> createState() => _HourlyWordCardState();
}

class _HourlyWordCardState extends ConsumerState<_HourlyWordCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleNextHour();
  }

  void _scheduleNextHour() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day, now.hour + 1);
    _timer = Timer(next.difference(now) + const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {});
      _scheduleNextHour();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Hours since 1970 (local): the same number for the whole hour, so the card is stable within it.
  int get _slot {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour).millisecondsSinceEpoch ~/ 3600000;
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(rulesProvider).valueOrNull;
    final active = (rules ?? const <Rule>[]).where((r) => !r.isArchived).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    if (active.isNotEmpty) return _ruleCard(context, active[_slot % active.length], active.length);
    return _verseCard(context);
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: AppTheme.goldDark));

  Widget _ruleCard(BuildContext context, Rule r, int total) {
    final hasDesc = (r.description ?? '').trim().isNotEmpty;
    return widget.card(
      onTap: () => context.push('/rules'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _label('YOUR RULE FOR THIS HOUR')),
          if (total > 1) Text('changes every hour', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ]),
        const SizedBox(height: 10),
        Text(r.title,
            style: TextStyle(fontFamily: 'Lora', fontSize: 21, height: 1.35, fontWeight: FontWeight.w600, color: AppTheme.ink)),
        if (hasDesc) ...[
          const SizedBox(height: 8),
          Text(r.description!.trim(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textSecondary)),
        ],
        if ((r.categoryName ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(r.categoryName!, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.goldDark, fontSize: 12)),
        ],
      ]),
    );
  }

  Widget _verseCard(BuildContext context) {
    final verse = ref.watch(verseOfTheDayProvider);
    final slot = _slot;
    // Slot 0 of each day-block is today's real Verse of the Day, the rest are the fallbacks.
    final n = _fallbackVerses.length + 1;
    final i = slot % n;
    final showServer = i == 0 && verse.hasValue;

    if (showServer) {
      final v = verse.value!;
      return widget.card(
        onTap: () => context.go(
            '/bible/chapter?book=${Uri.encodeComponent(v.bookName)}&chapter=${v.chapter}&translation=${v.translationCode}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label('VERSE FOR TODAY'),
          const SizedBox(height: 10),
          Text('\u201C${v.text}\u201D',
              style: TextStyle(fontFamily: 'Lora', fontSize: 20, height: 1.45, color: AppTheme.ink)),
          const SizedBox(height: 10),
          Text(v.reference, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.goldDark)),
        ]),
      );
    }
    final f = _fallbackVerses[i == 0 ? 0 : i - 1];
    return widget.card(
      onTap: () => context.go('/bible/chapter?book=${Uri.encodeComponent(f.$3)}&chapter=${f.$4}&translation=KJV'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('A VERSE FOR THIS HOUR'),
        const SizedBox(height: 10),
        Text('\u201C${f.$1}\u201D',
            style: TextStyle(fontFamily: 'Lora', fontSize: 20, height: 1.45, color: AppTheme.ink)),
        const SizedBox(height: 10),
        Text(f.$2, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.goldDark)),
      ]),
    );
  }
}
