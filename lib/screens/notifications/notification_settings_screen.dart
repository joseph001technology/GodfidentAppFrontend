import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../services/notification_service.dart';

/// State notifier for per-type notification preferences stored in SharedPreferences.
class NotificationPrefsNotifier extends StateNotifier<Map<String, bool>> {
  static const _prefix = 'notif_pref_';

  NotificationPrefsNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = {
      'prayer_reminders': prefs.getBool('${_prefix}prayer_reminders') ?? true,
      'bible_reading': prefs.getBool('${_prefix}bible_reading') ?? true,
      'daily_verse': prefs.getBool('${_prefix}daily_verse') ?? true,
      'devotional': prefs.getBool('${_prefix}devotional') ?? true,
      'focus_session': prefs.getBool('${_prefix}focus_session') ?? true,
      'weekly_recap': prefs.getBool('${_prefix}weekly_recap') ?? true,
      'achievement': prefs.getBool('${_prefix}achievement') ?? true,
    };
  }

  Future<void> toggle(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final current = state[key] ?? true;
    final updated = Map<String, bool>.from(state);
    updated[key] = !current;
    state = updated;
    await prefs.setBool('$_prefix$key', !current);
  }
}

final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsNotifier, Map<String, bool>>(
  (_) => NotificationPrefsNotifier(),
);

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);

    final sections = [
      {
        'title': 'Spiritual Practice',
        'items': [
          {
            'key': 'prayer_reminders',
            'label': 'Prayer Reminders',
            'subtitle': 'Scheduled reminders to pause and pray',
            'icon': Icons.volunteer_activism_outlined,
            'color': AppTheme.emerald,
          },
          {
            'key': 'bible_reading',
            'label': 'Bible Reading',
            'subtitle': 'Daily Bible reading nudges',
            'icon': Icons.menu_book_outlined,
            'color': AppTheme.softBlue,
          },
          {
            'key': 'focus_session',
            'label': 'Focus Sessions',
            'subtitle': 'Reminders to start focus & meditation',
            'icon': Icons.self_improvement_outlined,
            'color': AppTheme.accentPurple,
          },
        ],
      },
      {
        'title': 'Daily Content',
        'items': [
          {
            'key': 'daily_verse',
            'label': 'Verse of the Day',
            'subtitle': 'Morning scripture inspiration',
            'icon': Icons.format_quote_outlined,
            'color': AppTheme.gold,
          },
          {
            'key': 'devotional',
            'label': 'Devotionals',
            'subtitle': 'New devotional content alerts',
            'icon': Icons.auto_stories_outlined,
            'color': const Color(0xFFF59E0B),
          },
        ],
      },
      {
        'title': 'Progress & Milestones',
        'items': [
          {
            'key': 'weekly_recap',
            'label': 'Weekly Recap',
            'subtitle': 'Your spiritual summary every Sunday',
            'icon': Icons.bar_chart_outlined,
            'color': AppTheme.softBlue,
          },
          {
            'key': 'achievement',
            'label': 'Achievements',
            'subtitle': 'Celebrate spiritual milestones',
            'icon': Icons.emoji_events_outlined,
            'color': AppTheme.gold,
          },
        ],
      },
    ];

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: AppTheme.navySurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Notification Settings',
          style: TextStyle(
            fontFamily: 'Lora',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1E3A), Color(0xFF14142A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.gold.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_active_outlined,
                        color: AppTheme.gold, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stay Connected to God',
                          style: TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Manage which reminders keep you spiritually aligned.',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Test notification button
            GestureDetector(
              onTap: () async {
                await NotificationService().showNotification(
                  id: 9998,
                  title: '🔔 Godfident Test Notification',
                  body: '"Be still, and know that I am God." — Psalm 46:10',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test notification sent! Check your status bar.'),
                      backgroundColor: AppTheme.emerald,
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.send_outlined, color: AppTheme.emerald, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Send Test Notification',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.emerald,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.arrow_forward_ios, color: AppTheme.emerald, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Sections
            ...sections.map((section) {
              final title = section['title'] as String;
              final items = section['items'] as List<Map<String, dynamic>>;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 18,
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
                      children: items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final key = item['key'] as String;
                        final isEnabled = prefs[key] ?? true;
                        final color = item['color'] as Color;
                        return Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(item['icon'] as IconData,
                                    color: color, size: 20),
                              ),
                              title: Text(
                                item['label'] as String,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                item['subtitle'] as String,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              trailing: Switch(
                                value: isEnabled,
                                activeColor: color,
                                onChanged: (_) => ref
                                    .read(notificationPrefsProvider.notifier)
                                    .toggle(key),
                              ),
                            ),
                            if (idx < items.length - 1)
                              const Divider(height: 1, indent: 60),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            }),

            // Reminders shortcut
            GestureDetector(
              onTap: () => context.push('/reminders'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.navySurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.alarm_outlined, color: AppTheme.gold, size: 22),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage Scheduled Reminders',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Set recurring alarms for prayer & scripture',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
