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
      appBar: AppBar(title: const Text('Settings')),
      body: userAsync.when(
        loading: () => const ShimmerList(count: 6),
        error: (_, __) => const ErrorView(message: 'Could not load profile'),
        data: (user) => ListView(
          children: [
            // Profile header
            InkWell(
              onTap: () => context.push('/more/profile'),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.gold.withOpacity(0.2),
                      child: Text(
                        user?.initials ?? 'G',
                        style: const TextStyle(
                            color: AppTheme.gold,
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.displayName ?? '',
                              style: Theme.of(context).textTheme.titleLarge),
                          Text(user?.email ?? '',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            // Bible settings
            const SectionHeader(title: 'BIBLE'),
            ListTile(
              leading: const Icon(Icons.translate, color: AppTheme.gold),
              title: const Text('Preferred Translation'),
              subtitle: Text(user?.profile?.preferredTranslation ?? 'KJV'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () => context.push('/more/profile'),
            ),

            // Account
            const SectionHeader(title: 'ACCOUNT'),
            ListTile(
              leading: const Icon(Icons.lock_outline, color: Colors.grey),
              title: const Text('Change Password'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () => context.push('/more/change-password'),
            ),

            // Notifications
            const SectionHeader(title: 'NOTIFICATIONS'),
            ListTile(
              leading: const Icon(Icons.notifications_outlined, color: Colors.grey),
              title: const Text('Notification Preferences'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () => context.push('/more/profile'),
            ),

            const SizedBox(height: 16),

            // Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.withOpacity(0.5)),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppTheme.navySurface,
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sign Out',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(authActionProvider).logout();
                    if (context.mounted) context.go('/login');
                  }
                },
              ),
            ),
            const SizedBox(height: 32),

            Center(
              child: Text('Godfident v1.0.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
