import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.read(currentUserProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 52, 16, 24),
          child: userAsync.when(
            loading: () => const ShimmerList(count: 8),
            error: (_, __) => const ErrorView(message: 'Could not load profile'),
            data: (user) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileCard(user: user),
                const SizedBox(height: 24),
                const _SectionLabel('FEATURES'),
                const SizedBox(height: 8),
                _FeatureGrid(),
                const SizedBox(height: 24),
                const _SectionLabel('TOOLS'),
                const SizedBox(height: 8),
                _tile(context, Icons.note_alt_outlined, 'Notes', '/notes', AppTheme.gold),
                _tile(context, Icons.rule_outlined, 'Universal Rules', '/rules', AppTheme.accentPurple),
                _tile(context, Icons.alarm_outlined, 'Reminders', '/reminders', AppTheme.accentTeal),
                const SizedBox(height: 24),
                const _SectionLabel('ACCOUNT'),
                const SizedBox(height: 8),
                _tile(context, Icons.lock_outline, 'Change Password', '/settings/change-password', null),
                _tile(context, Icons.person_outline, 'Edit Profile', '/settings/profile', null),
                const SizedBox(height: 24),
                const _SectionLabel('ABOUT'),
                const SizedBox(height: 8),
                _tile(context, Icons.privacy_tip_outlined, 'Privacy Policy', null, null),
                const SizedBox(height: 24),
                _signOutButton(context, ref),
                const SizedBox(height: 20),
                const Center(child: Text('Godfident v1.0.0', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted))),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _signOutButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: BorderSide(color: Colors.red.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.logout),
        label: const Text('Sign Out'),
        onPressed: () async {
          final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
            backgroundColor: AppTheme.navySurface,
            title: const Text('Sign Out'),
            content: const Text('Are you sure?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out', style: TextStyle(color: Colors.red))),
            ],
          ));
          if (confirm == true) {
            await ref.read(authActionProvider).logout();
            if (context.mounted) context.go('/login');
          }
        },
      ),
    );
  }

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.gold, letterSpacing: 1)));
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();
  @override
  Widget build(BuildContext context) {
    final features = [
      {'icon': '🤖', 'label': 'AI Assistant', 'route': '/settings/ai'},
      {'icon': '✝️', 'label': 'Prayer', 'route': '/settings/prayer'},
      {'icon': '📖', 'label': 'Devotionals', 'route': '/settings/devotionals'},
      {'icon': '📚', 'label': 'Reading Plans', 'route': '/settings/plans'},
      {'icon': '🙏', 'label': 'Prayer Journal', 'route': '/settings/prayer'},
      {'icon': '📊', 'label': 'Analytics', 'route': '/settings/analytics'},
    ];
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.9),
      itemCount: features.length,
      itemBuilder: (_, i) {
        final f = features[i];
        return GestureDetector(
          onTap: () => context.push(f['route'] as String),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.navyOutline.withOpacity(0.5))),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(f['icon'] as String, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(f['label'] as String, textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            ]),
          ),
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final dynamic user;
  const _ProfileCard({required this.user});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/settings/profile'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          CircleAvatar(radius: 30, backgroundColor: AppTheme.gold.withOpacity(0.15),
            child: Text(user?.initials ?? 'G', style: const TextStyle(color: AppTheme.gold, fontSize: 22, fontWeight: FontWeight.w700))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user?.displayName ?? '', style: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(user?.email ?? '', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppTheme.textSecondary)),
          ])),
          const Icon(Icons.chevron_right, color: AppTheme.textMuted),
        ]),
      ),
    );
  }
}

Widget _tile(BuildContext context, IconData icon, String title, String? route, Color? iconColor) {
  return Container(
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(14)),
    child: ListTile(
      leading: Icon(icon, color: iconColor ?? AppTheme.textMuted, size: 22),
      title: Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
      trailing: route != null ? const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20) : null,
      onTap: route != null ? () => context.push(route) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

}
