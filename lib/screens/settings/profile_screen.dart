import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/common/app_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final prayerStreakAsync = ref.watch(prayerStreakProvider);
    final readingStreakAsync = ref.watch(readingStreakProvider);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 52, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Title
            const Text(
              'My Profile',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // User Card
            userAsync.when(
              loading: () => const LoadingShimmer(height: 120),
              error: (_, __) =>
                  _buildUserCard(context, ref, 'Faithful Servant', '@godfident_user', null),
              data: (user) {
                final name = (user?.firstName.isNotEmpty == true)
                    ? '${user!.firstName} ${user.lastName}'
                    : 'Faithful Servant';
                final handle = user?.email.isNotEmpty == true
                    ? '@${user!.email.split('@').first}'
                    : '@godfident_user';
                return _buildUserCard(context, ref, name, handle, user);
              },
            ),

            const SizedBox(height: 20),

            // Streak Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    label: 'Prayer Streak',
                    icon: Icons.volunteer_activism,
                    color: AppTheme.emerald,
                    value: prayerStreakAsync.when(
                      data: (s) => '${s.currentStreak}d 🔥',
                      loading: () => '—',
                      error: (_, __) => '0d',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    label: 'Bible Streak',
                    icon: Icons.menu_book,
                    color: AppTheme.softBlue,
                    value: readingStreakAsync.when(
                      data: (s) => '${s.currentStreak}d 📖',
                      loading: () => '—',
                      error: (_, __) => '0d',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Analytics — moved from bottom nav here
            _sectionTitle('Analytics'),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.push('/analytics'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF14142A), Color(0xFF1A1040)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.accentPurple.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentPurple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.analytics_outlined,
                          color: AppTheme.accentPurple, size: 26),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spiritual Dashboard',
                            style: TextStyle(
                                fontFamily: 'Lora',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'View streaks, progress & weekly insights',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppTheme.textMuted, size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Account section
            _sectionTitle('Account'),
            const SizedBox(height: 12),
            _settingsGroup([
              _SettingsTile(
                icon: Icons.lock_outlined,
                label: 'Change Password',
                color: AppTheme.gold,
                onTap: () => context.push('/profile/change-password'),
              ),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                label: 'Notification Settings',
                color: AppTheme.accentPurple,
                onTap: () => context.push('/notification-settings'),
              ),
              _SettingsTile(
                icon: Icons.settings_outlined,
                label: 'App Settings',
                color: AppTheme.textMuted,
                onTap: () => context.push('/profile/settings'),
              ),
            ]),

            const SizedBox(height: 24),

            // Quick Links
            _sectionTitle('Quick Links'),
            const SizedBox(height: 12),
            _settingsGroup([
              _SettingsTile(
                icon: Icons.alarm_outlined,
                label: 'Reminders & Alarms',
                color: AppTheme.gold,
                onTap: () => context.push('/reminders'),
              ),
              _SettingsTile(
                icon: Icons.emoji_events_outlined,
                label: 'Achievements',
                color: const Color(0xFFF59E0B),
                onTap: () => context.push('/more/achievements'),
              ),
              _SettingsTile(
                icon: Icons.self_improvement_outlined,
                label: 'Focus Sessions',
                color: AppTheme.emerald,
                onTap: () => context.push('/focus'),
              ),
              _SettingsTile(
                icon: Icons.smart_toy_outlined,
                label: 'AI Spiritual Assistant',
                color: AppTheme.accentPurple,
                onTap: () => context.push('/ai'),
              ),
            ]),

            const SizedBox(height: 24),

            // About
            _sectionTitle('About'),
            const SizedBox(height: 12),
            _settingsGroup([
              _SettingsTile(
                icon: Icons.shield_outlined,
                label: 'Privacy Policy',
                color: AppTheme.textMuted,
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                label: 'Terms of Service',
                color: AppTheme.textMuted,
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.info_outlined,
                label: 'App Version 1.0.0',
                color: AppTheme.textMuted,
                onTap: () {},
                trailing: const SizedBox.shrink(),
              ),
            ]),

            const SizedBox(height: 32),

            // Sign Out
            ElevatedButton.icon(
              onPressed: () async {
                await ref.read(authActionProvider).logout();
                if (context.mounted) context.go('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444).withOpacity(0.15),
                foregroundColor: const Color(0xFFEF4444),
                minimumSize: const Size(double.infinity, 50),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
                side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.3)),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    WidgetRef ref,
    String name,
    String handle,
    User? user,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14142A), Color(0xFF1E1E3A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.gold, Color(0xFFE8B84B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.person, color: AppTheme.navy, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  handle,
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppTheme.gold,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(
                      fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.textMuted, size: 20),
            onPressed: () => context.push('/profile/settings'),
            tooltip: 'Edit profile',
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required IconData icon,
    required Color color,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Lora',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _settingsGroup(List<_SettingsTile> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: tiles.asMap().entries.map((entry) {
          return Column(
            children: [
              entry.value,
              if (entry.key < tiles.length - 1)
                const Divider(height: 1, indent: 52),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      trailing: trailing ??
          const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
    );
  }
}
