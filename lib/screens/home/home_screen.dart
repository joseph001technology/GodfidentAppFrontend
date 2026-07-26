import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/common/app_widgets.dart';

// ──────────────────────────────────────────────
// Mood model (local, no backend needed)
// ──────────────────────────────────────────────
class _Mood {
  final String emoji;
  final String label;
  const _Mood(this.emoji, this.label);
}

const _moods = [
  _Mood('😊', 'Joyful'),
  _Mood('🙏', 'Peaceful'),
  _Mood('💪', 'Hopeful'),
  _Mood('😔', 'Low'),
  _Mood('🔥', 'On Fire'),
];

// ──────────────────────────────────────────────
// Worship Music model (static curated list)
// ──────────────────────────────────────────────
class _Song {
  final String title;
  final String artist;
  final String duration;
  final String platform; // 'spotify' | 'youtube'
  final String url;
  const _Song(this.title, this.artist, this.duration, this.platform, this.url);
}

const _songs = [
  _Song('Way Maker', 'Sinach', '4:32', 'spotify',
      'https://open.spotify.com/track/0BKEhH4gDgOEJRi3aBYdIA'),
  _Song('Goodness of God', 'Bethel Music', '5:14', 'spotify',
      'https://open.spotify.com/track/2WLTpvHHEKaWHSQb6mDlCx'),
  _Song('What a Beautiful Name', 'Hillsong', '4:58', 'youtube',
      'https://www.youtube.com/watch?v=nQWFzMvCfLE'),
];

// ──────────────────────────────────────────────
// Daily Inspiration categories (static)
// ──────────────────────────────────────────────
class _Inspiration {
  final String emoji;
  final String label;
  final Color bgColor;
  const _Inspiration(this.emoji, this.label, this.bgColor);
}

const _inspirations = [
  _Inspiration('☀️', 'Rise With Purpose', Color(0xFF7B3A10)),
  _Inspiration('🙌', 'Worship in Spirit', Color(0xFF2A1A6B)),
  _Inspiration('🌿', 'His Creation Speaks', Color(0xFF0D3D2A)),
];

// ──────────────────────────────────────────────
// Reminder model (local toggle state)
// ──────────────────────────────────────────────
class _Reminder {
  final String emoji;
  final String title;
  final String time;
  final String subtitle;
  bool enabled;
  _Reminder(this.emoji, this.title, this.time, this.subtitle,
      {this.enabled = true});
}

// ──────────────────────────────────────────────
// Home Screen
// ──────────────────────────────────────────────
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int? _selectedMood;

  final List<_Reminder> _reminders = [
    _Reminder('🙏', 'Morning Prayer', '6:00 AM', 'Start your day with God',
        enabled: true),
    _Reminder('📖', 'Read Scripture', '7:00 AM', 'Daily Bible reading',
        enabled: true),
    _Reminder('☀️', 'Midday Prayer', '12:00 PM', 'Pause and pray',
        enabled: false),
  ];

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning,';
    if (h < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final todayAsync = ref.watch(todayDevotionalProvider);
    final dashAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E2A),
      body: RefreshIndicator(
        color: AppTheme.gold,
        onRefresh: () async {
          ref.invalidate(todayDevotionalProvider);
          ref.invalidate(dashboardProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──────────────────────────────
            SliverAppBar(
              backgroundColor: const Color(0xFF0A0E2A),
              floating: true,
              elevation: 0,
              titleSpacing: 16,
              title: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.green.withOpacity(0.4), width: 0.5),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.wifi, color: Colors.green, size: 12),
                        SizedBox(width: 4),
                        Text('Online',
                            style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                Consumer(builder: (_, ref, __) {
                  final count = ref.watch(unreadCountProvider);
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined,
                            color: Colors.white, size: 26),
                        onPressed: () => context.push('/more/notifications'),
                      ),
                      if (count.value != null && count.value! > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: AppTheme.gold,
                                shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  );
                }),
                const SizedBox(width: 8),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Greeting ─────────────────────────
                  userAsync.when(
                    data: (user) => RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${_greeting()}\n',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w400),
                          ),
                          TextSpan(
                            text: 'Walk With God ',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(
                            text: 'Today',
                            style: TextStyle(
                                color: AppTheme.gold,
                                fontSize: 28,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    loading: () => const LoadingShimmer(height: 60),
                    error: (_, __) => const Text('Walk With God Today',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),

                  // ── Verse of the Day card ─────────────
                  todayAsync.when(
                    data: (d) => _VerseCard(
                      verse: '"${d.title}"',
                      reference: d.scriptureReference,
                      onTap: () =>
                          context.push('/more/devotionals/${d.id}'),
                    ),
                    loading: () => const LoadingShimmer(height: 140),
                    error: (_, __) => const _VerseCard(
                      verse:
                          '"I can do all things through Christ who strengthens me."',
                      reference: '— Philippians 4:13',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Mood check-in ─────────────────────
                  const _SectionLabel('How are you feeling?',
                      subtitle: 'Your spiritual mood today'),
                  const SizedBox(height: 12),
                  _MoodRow(
                    moods: _moods,
                    selected: _selectedMood,
                    onSelect: (i) => setState(() => _selectedMood = i),
                  ),
                  const SizedBox(height: 24),

                  // ── Today's Devotion checklist ────────
                  const _SectionLabel('Today\'s Devotion',
                      subtitle: 'Your daily spiritual checklist'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DailyCheckTile(
                          emoji: '🙏',
                          label: 'Daily Prayer',
                          hint: 'Tap to pray',
                          onTap: () => context.go('/prayer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DailyCheckTile(
                          emoji: '📖',
                          label: 'Read Bible',
                          hint: 'Tap to read',
                          onTap: () => context.go('/bible'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Today's Progress ──────────────────
                  dashAsync.when(
                    data: (dash) => _ProgressCard(dash: dash),
                    loading: () => const LoadingShimmer(height: 100),
                    error: (_, __) => const SizedBox(),
                  ),
                  const SizedBox(height: 24),

                  // ── Reminders ─────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionLabel('Reminders'),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Edit',
                            style: TextStyle(
                                color: AppTheme.gold,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._reminders.map((r) => _ReminderTile(
                        reminder: r,
                        onToggle: (v) =>
                            setState(() => r.enabled = v),
                      )),
                  const SizedBox(height: 24),

                  // ── Worship Music ─────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionLabel('Worship Music',
                          subtitle: 'Lift your spirit'),
                      TextButton(
                        onPressed: () {},
                        child: const Text('See all',
                            style: TextStyle(
                                color: AppTheme.gold,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._songs.map((s) => _SongTile(song: s)),
                  const SizedBox(height: 24),

                  // ── Daily Inspiration ─────────────────
                  const _SectionLabel('Daily Inspiration',
                      subtitle: 'Scenes of faith'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _inspirations.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 10),
                      itemBuilder: (_, i) =>
                          _InspirationCard(item: _inspirations[i]),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Continue Reading ──────────────────
                  dashAsync.when(
                    data: (dash) => _ContinueReadingCard(
                      location: dash.reading.lastReadLocation ??
                          'Psalm 23 — Verse 4',
                      progress: _clamp(
                          (dash.reading.chaptersThisWeek) / 49.0),
                      onTap: () => context.go('/bible'),
                    ),
                    loading: () => const LoadingShimmer(height: 90),
                    error: (_, __) => _ContinueReadingCard(
                      location: 'Psalm 23 — Verse 4',
                      progress: 0.25,
                      onTap: () => context.go('/bible'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Daily Encouragement button ────────
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.gold,
                      side: const BorderSide(
                          color: AppTheme.gold, width: 0.5),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Daily Encouragement'),
                    onPressed: () => _showEncouragement(context, ref),
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _clamp(double v) => v.clamp(0.0, 1.0);

  void _showEncouragement(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131730),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text('Daily Encouragement',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: AppTheme.gold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: enc.when(
                      data: (text) => Markdown(
                          data: text,
                          styleSheet: MarkdownStyleSheet.fromTheme(
                              Theme.of(context))),
                      loading: () => const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.gold)),
                      error: (_, __) =>
                          const Text('Could not load encouragement.'),
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

// ──────────────────────────────────────────────
// Sub-widgets
// ──────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionLabel(this.title, {this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        if (subtitle != null)
          Text(subtitle!,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }
}

class _VerseCard extends StatelessWidget {
  final String verse;
  final String reference;
  final VoidCallback? onTap;
  const _VerseCard({required this.verse, required this.reference, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7B3A10), Color(0xFF3A2060)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.diamond, color: AppTheme.gold, size: 14),
                SizedBox(width: 6),
                Text('VERSE OF THE DAY',
                    style: TextStyle(
                        color: AppTheme.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
              ],
            ),
            const SizedBox(height: 12),
            Text(verse,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    height: 1.5)),
            const SizedBox(height: 10),
            Text(reference,
                style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _MoodRow extends StatelessWidget {
  final List<_Mood> moods;
  final int? selected;
  final void Function(int) onSelect;
  const _MoodRow(
      {required this.moods, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(moods.length, (i) {
        final active = selected == i;
        return GestureDetector(
          onTap: () => onSelect(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 72,
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.gold.withOpacity(0.15)
                  : const Color(0xFF131730),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: active
                      ? AppTheme.gold
                      : Colors.white.withOpacity(0.08),
                  width: active ? 1.5 : 0.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(moods[i].emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(moods[i].label,
                    style: TextStyle(
                        color: active ? AppTheme.gold : Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _DailyCheckTile extends StatefulWidget {
  final String emoji;
  final String label;
  final String hint;
  final VoidCallback onTap;
  const _DailyCheckTile(
      {required this.emoji,
      required this.label,
      required this.hint,
      required this.onTap});

  @override
  State<_DailyCheckTile> createState() => _DailyCheckTileState();
}

class _DailyCheckTileState extends State<_DailyCheckTile> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _checked = !_checked);
        widget.onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF131730),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _checked
                  ? AppTheme.gold.withOpacity(0.5)
                  : Colors.white.withOpacity(0.07),
              width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.emoji,
                    style: const TextStyle(fontSize: 28)),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _checked
                            ? AppTheme.gold
                            : Colors.white30,
                        width: 1.5),
                    color: _checked
                        ? AppTheme.gold.withOpacity(0.2)
                        : Colors.transparent,
                  ),
                  child: _checked
                      ? const Icon(Icons.check,
                          size: 14, color: AppTheme.gold)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(widget.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            Text(widget.hint,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final dynamic dash;
  const _ProgressCard({required this.dash});

  @override
  Widget build(BuildContext context) {
    final streak = dash.reading.currentStreak as int? ?? 0;
    final chapters = dash.reading.chaptersThisWeek as int? ?? 0;
    final prayers = dash.prayer.totalPrayers as int? ?? 0;
    // Mock goal completion %
    final pct = ((streak * 5 + chapters * 3 + prayers * 2).clamp(0, 100));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131730),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withOpacity(0.07), width: 0.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: pct / 100,
                  strokeWidth: 6,
                  backgroundColor: Colors.white12,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.gold),
                ),
                Center(
                  child: Text('$pct%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Today's Progress",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Text('Start your devotion',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _MiniStat('🔥', '${streak}d'),
                  const SizedBox(width: 12),
                  _MiniStat('📖', '${chapters}d'),
                  const SizedBox(width: 12),
                  _MiniStat('🎯', '$pct%',
                      color: Colors.green),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String emoji;
  final String value;
  final Color color;
  const _MiniStat(this.emoji, this.value,
      {this.color = AppTheme.gold});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 3),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final _Reminder reminder;
  final void Function(bool) onToggle;
  const _ReminderTile({required this.reminder, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131730),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withOpacity(0.07), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
                child: Text(reminder.emoji,
                    style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reminder.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text('${reminder.time} · ${reminder.subtitle}',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: reminder.enabled,
            onChanged: onToggle,
            activeColor: AppTheme.gold,
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final _Song song;
  const _SongTile({required this.song});

  Color get _platformColor => song.platform == 'spotify'
      ? const Color(0xFF1DB954)
      : const Color(0xFFFF0000);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131730),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withOpacity(0.07), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white70, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(song.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text('${song.artist} · ${song.duration}',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _platformColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _platformColor.withOpacity(0.5), width: 0.5),
            ),
            child: Text(
              song.platform == 'spotify' ? 'Spotify' : 'YouTube',
              style: TextStyle(
                  color: _platformColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _InspirationCard extends StatelessWidget {
  final _Inspiration item;
  const _InspirationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      decoration: BoxDecoration(
        color: item.bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(item.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  final String location;
  final double progress;
  final VoidCallback onTap;
  const _ContinueReadingCard(
      {required this.location,
      required this.progress,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1040),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.gold.withOpacity(0.2), width: 0.5),
        ),
        child: Row(
          children: [
            const Text('📖', style: TextStyle(fontSize: 36)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Continue Reading',
                      style: TextStyle(
                          color: AppTheme.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(location,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.gold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right,
                color: Colors.white54, size: 22),
          ],
        ),
      ),
    );
  }
}