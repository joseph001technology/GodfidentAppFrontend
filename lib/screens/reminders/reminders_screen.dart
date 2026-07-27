import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/reminder.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/common/app_widgets.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(remindersProvider);

    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Text('🔔 ', style: TextStyle(fontSize: 20)),
            Text(
              'Spiritual Reminders',
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.gold),
            onPressed: () => context.push('/reminders/new'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(remindersProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E1E3A), Color(0xFF14142A)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.gold.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.alarm_on_outlined, color: AppTheme.gold, size: 32),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Spiritual Rhythm',
                            style: TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Set reminders to pause, pray, and meditate.',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Active Timers & Notifications',
                style: TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),

              const SizedBox(height: 12),

              remindersAsync.when(
                loading: () => const LoadingShimmer(height: 200),
                error: (e, _) => ErrorView(message: e.toString()),
                data: (reminders) {
                  if (reminders.isEmpty) return _buildDefaultReminders(context);
                  return Column(
                    children: reminders.map((r) => _buildReminderCard(context, r)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, Reminder r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.notifications_active_outlined, color: AppTheme.gold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.title,
                  style: const TextStyle(fontFamily: 'Lora', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  r.formattedTime.isNotEmpty ? r.formattedTime : 'Daily at 7:00 AM',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: r.isActive,
            onChanged: (v) {},
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultReminders(BuildContext context) {
    final list = [
      {'title': 'Morning Prayer', 'time': '6:00 AM · Daily', 'cat': 'Prayer', 'active': true},
      {'title': 'Scripture Reading', 'time': '7:00 AM · Daily', 'cat': 'Scripture', 'active': true},
      {'title': 'Midday Reflection', 'time': '12:00 PM · Daily', 'cat': 'Devotion', 'active': false},
      {'title': 'Evening Gratitude Journal', 'time': '9:00 PM · Daily', 'cat': 'Reflection', 'active': true},
    ];

    return Column(
      children: list.map((item) {
        final isActive = item['active'] as bool;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.navySurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.notifications_active_outlined, color: AppTheme.gold, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] as String,
                      style: const TextStyle(fontFamily: 'Lora', fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['time'] as String,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                onChanged: (v) {},
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
