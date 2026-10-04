import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/activity.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/common/app_widgets.dart';

/// The Profile tab: who you are, your REAL numbers, and every setting that
/// actually works. Rows that did nothing (Privacy, Terms, dead "App Settings")
/// were removed.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final overview = ref.watch(overviewProvider);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.gold,
          onRefresh: () async {
            ref.invalidate(overviewProvider);
            await ref.read(currentUserProvider.notifier).refresh();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              const Text('Profile',
                  style: TextStyle(fontFamily: 'Lora', fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.inkNavy)),
              const SizedBox(height: 16),
              userAsync.when(
                loading: () => const LoadingShimmer(height: 150),
                error: (_, __) => _header(context, null, overview.valueOrNull),
                data: (u) => _header(context, u, overview.valueOrNull),
              ),
              const SizedBox(height: 16),
              overview.when(
                loading: () => const LoadingShimmer(height: 170),
                error: (e, _) => ErrorView(message: friendlyError(e), onRetry: () => ref.invalidate(overviewProvider)),
                data: _stats,
              ),
              const SizedBox(height: 22),
              _group('My Journey', [
                _Row(Icons.insights_outlined, 'My Activity', 'Calendar, streaks and what you did each day', AppTheme.gold, () => context.push('/analytics')),
                _Row(Icons.emoji_events_outlined, 'Achievements', null, AppTheme.goldDark, () => context.push('/more/achievements')),
              ]),
              _group('Protect my time', [
                _Row(Icons.shield_outlined, 'Focus sessions', 'Schedule and start time with God', AppTheme.emerald, () => context.go('/focus')),
                _Row(Icons.apps_rounded, 'App restrictions', null, AppTheme.emerald, () => context.push('/focus/apps')),
                _Row(Icons.language_rounded, 'Website protection', null, AppTheme.emerald, () => context.push('/focus/websites')),
                _Row(Icons.verified_user_outlined, 'Permissions', 'What Android must allow for protection to work', AppTheme.goldDark, () => context.push('/focus/permissions')),
              ]),
              _group('My tools', [
                _Row(Icons.alarm_outlined, 'Reminders', null, AppTheme.gold, () => context.go('/reminders')),
                _Row(Icons.edit_note, 'Notes & rules', null, AppTheme.softBlue, () => context.push('/notes')),
                _Row(Icons.library_music_outlined, 'Music', null, AppTheme.accentPurple, () => context.push('/music')),
              ]),
              _group('Account', [
                _Row(Icons.person_outline, 'Edit profile', null, AppTheme.inkNavy, () => context.push('/profile/edit')),
                _Row(Icons.lock_outlined, 'Change password', null, AppTheme.inkNavy, () => context.push('/profile/change-password')),
                _Row(Icons.notifications_outlined, 'Notification settings', null, AppTheme.inkNavy, () => context.push('/notification-settings')),
              ]),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => _signOut(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.5)),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 16),
              const Center(child: Text('Godfident · Make Time for God', style: TextStyle(fontSize: 12, color: AppTheme.textMuted))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your protected websites and reminders stay safe on your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authActionProvider).logout();
    if (context.mounted) context.go('/login');
  }

  Widget _header(BuildContext context, User? u, Overview? o) {
    final name = (u?.fullName.isNotEmpty ?? false) && u!.fullName != u.email ? u.fullName : 'Faithful servant';
    final since = o?.memberSince ?? DateTime.tryParse(u?.dateJoined ?? '');
    final bio = u?.profile?.bio ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.inkNavy, Color(0xFF2A3B63)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 66,
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.gold, AppTheme.goldLight]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(u?.initials ?? 'G',
                style: const TextStyle(fontFamily: 'Lora', fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.inkNavy)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontFamily: 'Lora', fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textOnDark)),
              const SizedBox(height: 2),
              Text(u?.email ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textOnDarkMuted)),
              if (since != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('With Godfident since ${_months[since.month - 1]} ${since.year}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.goldLight)),
                ),
            ]),
          ),
          IconButton(
            tooltip: 'Edit profile',
            onPressed: () => context.push('/profile/edit'),
            icon: const Icon(Icons.edit_outlined, color: AppTheme.goldLight),
          ),
        ]),
        if (bio.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(bio, style: const TextStyle(color: AppTheme.textOnDarkMuted, height: 1.4, fontSize: 13)),
        ],
        if (u != null && !u.isEmailVerified) ...[
          const SizedBox(height: 12),
          const Row(children: [
            Icon(Icons.info_outline, size: 16, color: AppTheme.goldLight),
            SizedBox(width: 6),
            Expanded(child: Text('Your email is not verified yet.', style: TextStyle(fontSize: 12, color: AppTheme.goldLight))),
          ]),
        ],
      ]),
    );
  }

  Widget _stats(Overview o) {
    Widget tile(IconData i, Color c, String v, String l) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.navySurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.navyOutline),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(i, color: c, size: 20),
              const SizedBox(height: 8),
              Text(v, style: const TextStyle(fontFamily: 'Lora', fontSize: 21, fontWeight: FontWeight.bold, color: AppTheme.inkNavy)),
              Text(l, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ]),
          ),
        );
    return Column(children: [
      Row(children: [
        tile(Icons.shield, AppTheme.emerald, Overview.minutes(o.protectedMinutes), 'Protected time'),
        const SizedBox(width: 12),
        tile(Icons.check_circle_outline, AppTheme.emerald, '${o.completedSessions}', 'Focus sessions completed'),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        tile(Icons.local_fire_department, AppTheme.gold, '${o.readingStreak}d', 'Bible reading streak'),
        const SizedBox(width: 12),
        tile(Icons.menu_book_outlined, AppTheme.gold, '${o.chaptersTotal}', 'Chapters read'),
      ]),
    ]);
  }

  Widget _group(String title, List<_Row> rows) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title.toUpperCase(),
                style: const TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.navySurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.navyOutline),
            ),
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i < rows.length - 1) const Divider(height: 1, indent: 58),
              ],
            ]),
          ),
        ]),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final Color color;
  final VoidCallback onTap;
  const _Row(this.icon, this.label, this.sub, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        subtitle: sub == null ? null : Text(sub!, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
      );
}
