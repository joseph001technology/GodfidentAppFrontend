import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/reminder.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bible_provider.dart';
import '../../providers/focus_provider.dart';
import '../../providers/remaining_providers.dart';
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
                        style: const TextStyle(
                            fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                    const SizedBox(height: 2),
                    Text(first.isEmpty ? 'Welcome' : first,
                        style: const TextStyle(
                            fontFamily: 'Lora', fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.inkNavy)),
                  ]),
                ),
                IconButton(
                  onPressed: () => context.push('/global-search'),
                  icon: const Icon(Icons.search, color: AppTheme.inkNavy),
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

              // Verse of the day
              verse.when(
                loading: () => const LoadingShimmer(height: 150),
                error: (e, _) => ErrorView(
                  message: 'Verse of the day could not be loaded.\n${friendlyError(e)}',
                  onRetry: () => ref.invalidate(verseOfTheDayProvider),
                ),
                data: (v) => _card(
                  onTap: () => context.go(
                      '/bible/chapter?book=${Uri.encodeComponent(v.bookName)}&chapter=${v.chapter}&translation=${v.translationCode}'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('VERSE FOR TODAY',
                        style: TextStyle(
                            fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: AppTheme.goldDark)),
                    const SizedBox(height: 10),
                    Text('\u201C${v.text}\u201D',
                        style: const TextStyle(
                            fontFamily: 'Lora', fontSize: 20, height: 1.45, color: AppTheme.inkNavy)),
                    const SizedBox(height: 10),
                    Text(v.reference,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.goldDark)),
                  ]),
                ),
              ),
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
                        const Icon(Icons.chevron_right, color: AppTheme.textMuted),
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
                error: (e, _) => Text(friendlyError(e), style: const TextStyle(color: AppTheme.textSecondary)),
                data: (list) {
                  final active = list.where((r) => r.isActive).take(3).toList();
                  if (active.isEmpty) {
                    return const Padding(
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
      style: const TextStyle(fontFamily: 'Lora', fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.inkNavy));

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
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.inkNavy)),
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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
          Text(r.formattedTime, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
