import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _darkMode = true;
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 52, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Banner matching Screenshot 11
            userAsync.when(
              loading: () => const LoadingShimmer(height: 120),
              error: (_, __) => _buildUserCard('Faithful Servant', '@godfident_user'),
              data: (user) {
                final name = (user?.firstName.isNotEmpty == true) ? '${user!.firstName} ${user.lastName}' : 'Faithful Servant';
                final handle = user?.email.isNotEmpty == true ? '@${user!.email.split('@').first}' : '@godfident_user';
                return _buildUserCard(name, handle);
              },
            ),

            const SizedBox(height: 24),

            // Features Grid
            const Text(
              'Features',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push('/ai'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.navySurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.accentPurple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.smart_toy_outlined, color: AppTheme.accentPurple, size: 24),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'AI Assistant',
                            style: TextStyle(fontFamily: 'Lora', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Get encouraged',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push('/prayer'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.navySurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.softBlue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.book_outlined, color: AppTheme.softBlue, size: 24),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Prayer Journal',
                            style: TextStyle(fontFamily: 'Lora', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Write & reflect',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Preferences
            const Text(
              'Preferences',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.navySurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.dark_mode_outlined, color: AppTheme.gold, size: 20),
                    ),
                    title: const Text(
                      'Dark Mode',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    value: _darkMode,
                    activeColor: AppTheme.gold,
                    onChanged: (v) => setState(() => _darkMode = v),
                  ),
                  const Divider(height: 1, indent: 60),
                  SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_outlined, color: AppTheme.gold, size: 20),
                    ),
                    title: const Text(
                      'Notifications',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    value: _notifications,
                    activeColor: AppTheme.gold,
                    onChanged: (v) => setState(() => _notifications = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // About
            const Text(
              'About',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.navySurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.shield_outlined, color: AppTheme.textMuted, size: 20),
                    title: const Text('Privacy Policy', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textPrimary)),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 50),
                  ListTile(
                    leading: const Icon(Icons.description_outlined, color: AppTheme.textMuted, size: 20),
                    title: const Text('Terms of Service', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppTheme.textPrimary)),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Logout Button
            ElevatedButton.icon(
              onPressed: _handleLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444).withOpacity(0.15),
                foregroundColor: const Color(0xFFEF4444),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign Out', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    await ref.read(authActionProvider).logout();
    if (context.mounted) context.go('/login');
  }

  Widget _buildUserCard(String name, String handle) {
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.gold,
              borderRadius: BorderRadius.circular(18),
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
                  style: const TextStyle(fontFamily: 'Lora', fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                Text(
                  handle,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.gold, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Member since January 2025',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
