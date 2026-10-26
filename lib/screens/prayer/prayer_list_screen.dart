import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/prayer.dart';
import '../../models/scheduled_focus.dart';
import '../../providers/remaining_providers.dart';
import '../../services/focus_session_manager.dart';
import '../../services/prayer_notifications.dart';
import '../../services/session_ticker.dart';
import '../../widgets/common/app_widgets.dart';
import 'prayer_launch.dart';

class PrayerListScreen extends ConsumerStatefulWidget {
  const PrayerListScreen({super.key});

  @override
  ConsumerState<PrayerListScreen> createState() => _PrayerListScreenState();
}

class _PrayerListScreenState extends ConsumerState<PrayerListScreen> {
  /// 'active' | 'answered' | 'all'
  String _status = 'active';

  /// 'all' or a prayer type.
  String _type = 'all';
  bool _prayedToday = false;

  static const _types = <(String, String)>[
    ('all', 'All types'),
    ('request', 'Requests'),
    ('praise', 'Praise'),
    ('intercession', 'Intercession'),
    ('thanksgiving', 'Thanksgiving'),
  ];

  @override
  void initState() {
    super.initState();
    PrayerNotifications.ensureScheduled();
    _refreshPrayed();
  }

  Future<void> _refreshPrayed() async {
    final v = await prayedToday();
    if (mounted) setState(() => _prayedToday = v);
  }

  Future<void> _addPrayer() async {
    await context.push('/prayer/new');
    if (!mounted) return;
    ref.read(prayerListProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Prayer>>>(prayerListProvider, (prev, next) {
      final list = next.valueOrNull;
      if (list != null) PrayerNotifications.syncWithPrayers(list);
    });
    final prayersAsync = ref.watch(prayerListProvider);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Prayer',
          style: TextStyle(fontFamily: 'Lora', fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.ink),
        ),
        actions: [
          IconButton(
            tooltip: 'Prayer insights',
            icon: const Icon(Icons.insights_outlined, color: AppTheme.goldDark),
            onPressed: () => context.push('/prayer/stats'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.inkNavy,
        shape: const StadiumBorder(), // a pill: the label sits inside the button, not outside a circle
        onPressed: _addPrayer,
        icon: const Icon(Icons.add),
        label: const Text('New request', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: AppTheme.gold,
        onRefresh: () async {
          await ref.read(prayerListProvider.notifier).load();
          await _refreshPrayed();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _focusHero(context),
              const SizedBox(height: 14),
              prayersAsync.when(
                loading: () => const LoadingShimmer(height: 200),
                error: (e, _) => ErrorView(
                  message: friendlyError(e),
                  onRetry: () => ref.read(prayerListProvider.notifier).load(),
                ),
                data: (prayers) => _content(context, prayers),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<Prayer> prayers) {
    final active = prayers.where((p) => !p.isAnswered).length;
    final answered = prayers.where((p) => p.isAnswered).length;
    final filtered = prayers.where((p) {
      if (_status == 'active' && p.isAnswered) return false;
      if (_status == 'answered' && !p.isAnswered) return false;
      // An answered prayer counts as a thanksgiving prayer.
      if (_type != 'all' && p.displayType.toLowerCase() != _type) return false;
      return true;
    }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _miniStat(Icons.volunteer_activism_outlined, '$active', 'Active')),
        const SizedBox(width: 10),
        Expanded(child: _miniStat(Icons.check_circle_outline, '$answered', 'Answered')),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStat(
            _prayedToday ? Icons.favorite : Icons.favorite_border,
            _prayedToday ? 'Yes' : 'Not yet',
            'Prayed today',
          ),
        ),
      ]),
      const SizedBox(height: 16),
      // Status filter
      Row(children: [
        _statusChip('active', 'Active', active),
        const SizedBox(width: 8),
        _statusChip('answered', 'Answered', answered),
        const SizedBox(width: 8),
        _statusChip('all', 'All', prayers.length),
      ]),
      const SizedBox(height: 10),
      // Type filter
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final t in _types)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t.$2),
                  selected: _type == t.$1,
                  showCheckmark: false,
                  selectedColor: AppTheme.goldLight,
                  backgroundColor: AppTheme.navySurface,
                  side: BorderSide(color: _type == t.$1 ? AppTheme.goldLight : AppTheme.navyOutline),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _type == t.$1 ? AppTheme.inkNavy : AppTheme.textPrimary,
                  ),
                  onSelected: (_) => setState(() => _type = t.$1),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (filtered.isEmpty)
        _emptyState(context, hasAny: prayers.isNotEmpty)
      else
        for (final p in filtered) _buildPrayerCard(context, ref, p),
    ]);
  }

  /// The Focus session card. Idle: pick a time and start. While a session runs or
  /// is frozen it shows the SAME live countdown as the Focus page, and the chips
  /// add prayer time to it. Colours come from the hero tokens, so the card
  /// follows Light and Dark like every other card.
  Widget _focusHero(BuildContext context) {
    return ValueListenableBuilder<SessionSnapshot>(
      valueListenable: SessionTicker.instance,
      builder: (context, snap, _) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.heroSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.heroBorder),
        ),
        child: snap.active ? _liveSession(context, snap) : _idleSession(context),
      ),
    );
  }

  Widget _heroIcon(IconData icon) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppTheme.gold.withValues(alpha: 0.18), shape: BoxShape.circle),
        child: Icon(icon, color: AppTheme.heroAccent, size: 26),
      );

  Widget _idleSession(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _heroIcon(Icons.self_improvement),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Focus session',
                style: TextStyle(fontFamily: 'Lora', fontSize: 19, fontWeight: FontWeight.bold, color: AppTheme.onHero)),
            const SizedBox(height: 2),
            Text('Choose your time, silence distractions and pray.',
                style: TextStyle(color: AppTheme.onHeroMuted, fontSize: 12.5)),
          ]),
        ),
      ]),
      const SizedBox(height: 14),
      Text('START NOW',
          style: TextStyle(fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: AppTheme.heroAccent)),
      const SizedBox(height: 8),
      Row(children: [
        const Expanded(child: PrayerDurationChips(minutes: [5, 15, 30])),
        TextButton(
          onPressed: () => openPrayerFocus(context),
          style: TextButton.styleFrom(foregroundColor: AppTheme.heroAccent),
          child: const Text('Choose time'),
        ),
      ]),
    ]);
  }

  Widget _liveSession(BuildContext context, SessionSnapshot snap) {
    final info = snap.info;
    final purpose = ScheduledFocus.purposes[info.purpose] ?? 'Time with God';
    final name = info.title.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _heroIcon(snap.frozen ? Icons.ac_unit_rounded : Icons.self_improvement),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(snap.frozen ? 'Session frozen' : 'Focus session running',
                style: TextStyle(fontFamily: 'Lora', fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.onHero)),
            const SizedBox(height: 2),
            Text(name.isEmpty ? purpose : '$name · $purpose',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.onHeroMuted, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(width: 8),
        Text(
          formatSessionLeft(snap.left),
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: snap.frozen ? AppTheme.onHeroMuted : AppTheme.onHero,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ]),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: snap.progress,
          minHeight: 5,
          color: AppTheme.heroAccent,
          backgroundColor: AppTheme.heroTrack,
        ),
      ),
      if (snap.frozen)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text("You haven't finished yet. Resume when you are ready.",
              style: TextStyle(color: AppTheme.onHeroMuted, fontSize: 12)),
        ),
      const SizedBox(height: 14),
      Text('ADD PRAYER TIME',
          style: TextStyle(fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: AppTheme.heroAccent)),
      const SizedBox(height: 8),
      Row(children: [
        const Expanded(child: PrayerDurationChips(minutes: [5, 15, 30])),
        if (snap.frozen)
          TextButton(
            onPressed: () => SessionManager.instance.resume(),
            style: TextButton.styleFrom(foregroundColor: AppTheme.heroAccent),
            child: const Text('Resume'),
          ),
        TextButton(
          onPressed: () => context.go('/focus'),
          style: TextButton.styleFrom(foregroundColor: AppTheme.heroAccent),
          child: const Text('Open'),
        ),
      ]),
    ]);
  }

  Widget _miniStat(IconData icon, String value, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.navyOutline),
        ),
        child: Column(children: [
          Icon(icon, color: AppTheme.goldDark, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.ink)),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ]),
      );

  Widget _statusChip(String key, String label, int count) {
    final sel = _status == key;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _status = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? AppTheme.gold : AppTheme.navySurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? AppTheme.gold : AppTheme.navyOutline),
          ),
          child: Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: sel ? AppTheme.inkNavy : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, {required bool hasAny}) {
    final answeredView = _status == 'answered';
    final String title;
    final String body;
    final String verse;
    final String reference;
    if (!hasAny) {
      title = 'Bring it all to God';
      body = 'Your prayer list is empty. Write down what is on your heart, and watch what God does.';
      verse = 'Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.';
      reference = 'Philippians 4:6';
    } else if (answeredView) {
      title = 'No answered prayers yet';
      body = 'Keep praying. When God answers, mark the request as answered and keep a record of His faithfulness.';
      verse = 'Is anything too hard for the Lord?';
      reference = 'Genesis 18:14';
    } else {
      title = 'Nothing here right now';
      body = 'No prayers match this filter. Add a new request or try another filter.';
      verse = 'Pray without ceasing.';
      reference = '1 Thessalonians 5:17';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.navyOutline),
      ),
      child: Column(children: [
        Icon(answeredView ? Icons.celebration_outlined : Icons.volunteer_activism_outlined, size: 40, color: AppTheme.goldDark),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Lora', fontSize: 19, fontWeight: FontWeight.bold, color: AppTheme.ink)),
        const SizedBox(height: 8),
        Text(body,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.45, color: AppTheme.textSecondary)),
        const SizedBox(height: 14),
        Text('“$verse”',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Lora', fontStyle: FontStyle.italic, fontSize: 14.5, height: 1.45, color: AppTheme.ink)),
        const SizedBox(height: 4),
        Text(reference, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppTheme.goldDark)),
        const SizedBox(height: 16),
        Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 8, children: [
          ElevatedButton.icon(
            onPressed: _addPrayer,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: AppTheme.inkNavy),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add a prayer request'),
          ),
          OutlinedButton.icon(
            onPressed: () => openPrayerFocus(context),
            icon: const Icon(Icons.self_improvement, size: 18),
            label: const Text('Focus session'),
          ),
        ]),
      ]),
    );
  }

  Widget _buildPrayerCard(BuildContext context, WidgetRef ref, Prayer prayer) {
    return GestureDetector(
      onTap: () async {
        await context.push('/prayer/${prayer.id}');
        if (!mounted) return;
        ref.read(prayerListProvider.notifier).load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: prayer.isAnswered ? AppTheme.emerald.withValues(alpha: 0.4) : AppTheme.navyOutline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        prayer.isAnswered ? Icons.check_circle : Icons.volunteer_activism,
                        color: prayer.isAnswered ? AppTheme.emerald : AppTheme.gold,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          prayer.title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Lora', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                if (prayer.isAnswered)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('ANSWERED', style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                  )
                else
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 18, color: AppTheme.textMuted),
                    onPressed: () async {
                      await context.push('/prayer/${prayer.id}/edit');
                      if (!mounted) return;
                      ref.read(prayerListProvider.notifier).load();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              prayer.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    'Prayed ${prayer.timesPrayed}×',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.gold),
                  ),
                  // Once answered, a prayer is kept as a thanksgiving prayer.
                  if (prayer.isAnswered) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('THANKSGIVING',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.goldAccent)),
                    ),
                  ],
                ]),
                if (!prayer.isAnswered)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final repo = ref.read(prayerRepositoryProvider);
                      final notifier = ref.read(prayerListProvider.notifier);
                      try {
                        await repo.recordPrayer(prayer.id);
                        await notifier.load();
                        messenger.showSnackBar(const SnackBar(content: Text('Prayer recorded. Amen.')));
                      } catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
                      }
                      _refreshPrayed();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold.withValues(alpha: 0.15),
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
      ),
    );
  }
}
