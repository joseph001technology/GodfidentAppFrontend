import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/reminder.dart';
import '../../providers/reminders_provider.dart';
import '../../widgets/common/app_widgets.dart';
import '../../services/notification_service.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            icon: const Icon(Icons.notifications_active, color: AppTheme.gold),
            tooltip: 'Test Notification',
            onPressed: () async {
              await NotificationService().showNotification(
                id: 9999,
                title: 'Godfident Spiritual Alert 🔔',
                body: 'Seek first His kingdom and His righteousness. — Matthew 6:33',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Test notification triggered! 🔔'),
                    backgroundColor: AppTheme.emerald,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.gold),
            onPressed: () => context.push('/reminders/new'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(remindersProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner
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
                            style: TextStyle(
                                fontFamily: 'Lora',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Set reminders to pause, pray, and meditate.',
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

              const Text(
                'Active Timers & Notifications',
                style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary),
              ),

              const SizedBox(height: 12),

              remindersAsync.when(
                loading: () => const LoadingShimmer(height: 200),
                error: (e, _) => ErrorView(message: e.toString()),
                data: (reminders) {
                  if (reminders.isEmpty) {
                    return EmptyView(
                      title: 'No reminders yet',
                      subtitle: 'Tap + to create your first spiritual reminder',
                      icon: Icons.alarm_add_outlined,
                      onAction: () => context.push('/reminders/new'),
                      actionLabel: 'Add Reminder',
                    );
                  }
                  return Column(
                    children: reminders
                        .map((r) => _ReminderCard(reminder: r))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  final Reminder reminder;

  const _ReminderCard({required this.reminder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = reminder;
    final isEnabled = r.isEnabled;

    // Icon based on recurrence type
    final IconData typeIcon = r.isAlarm
        ? Icons.alarm_outlined
        : r.recurrence == 'daily'
            ? Icons.repeat
            : r.recurrence == 'weekly'
                ? Icons.calendar_view_week_outlined
                : Icons.notifications_none_outlined;

    final accentColor = isEnabled ? AppTheme.gold : AppTheme.textMuted;

    return Dismissible(
      key: Key('reminder_${r.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppTheme.navySurface,
            title: const Text('Delete Reminder',
                style: TextStyle(color: AppTheme.textPrimary)),
            content: Text('Delete "${r.title}"?',
                style: const TextStyle(color: AppTheme.textMuted)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel',
                    style: TextStyle(color: AppTheme.textMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(remindersProvider.notifier).delete(r.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${r.title}"'),
            backgroundColor: AppTheme.navySurface,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => context.push('/reminders/${r.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.navySurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isEnabled
                  ? AppTheme.gold.withOpacity(0.3)
                  : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(typeIcon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isEnabled
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      r.formattedTime.isNotEmpty
                          ? r.formattedTime
                          : 'Daily',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: isEnabled
                            ? AppTheme.textMuted
                            : AppTheme.textMuted.withOpacity(0.5),
                      ),
                    ),
                    if (r.isAlarm) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Alarm',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentPurple),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                activeColor: AppTheme.gold,
                onChanged: (_) {
                  ref.read(remindersProvider.notifier).toggleEnabled(r.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
