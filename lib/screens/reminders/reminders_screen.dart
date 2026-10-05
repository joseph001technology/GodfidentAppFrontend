import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/ringtone_store.dart';
import '../../models/reminder.dart';
import '../../providers/reminders_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/common/app_widgets.dart';
import '../../widgets/common/delete_reminder.dart';

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
              final messenger = ScaffoldMessenger.of(context);
              final granted = await Permission.notification.isGranted;
              if (!granted) {
                messenger.showSnackBar(const SnackBar(
                  content: Text('Notifications are switched off for Godfident. Open Profile \u2192 Permissions to turn them on.'),
                  backgroundColor: AppTheme.danger,
                ));
                return;
              }
              final svc = NotificationService();
              final tone = await RingtoneStore.instance.load(0);
              await svc.showNow(const Reminder(
                id: 0,
                title: 'Test reminder',
                description: 'If you can see and hear this, reminders will reach you.',
                date: '',
                createdAt: '',
              ));
              final pending = await svc.pendingCount();
              messenger.showSnackBar(SnackBar(
                content: Text('Test sent with "${tone.title}". $pending reminder${pending == 1 ? '' : 's'} scheduled on this phone.'),
                backgroundColor: AppTheme.emerald,
              ));
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  // was a dark [#1E1E3A, #14142A] gradient — flattened,
                  // same reasoning as the other "motivational banner" cards
                  color: AppTheme.navySurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
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
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Set reminders to pause, pray, and meditate.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
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
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              remindersAsync.when(
                loading: () => const LoadingShimmer(height: 200),
                error: (e, _) => ErrorView(message: friendlyError(e)),
                data: (reminders) {
                  if (reminders.isEmpty) {
                    return EmptyView(
                      title: 'No reminders yet',
                      subtitle: 'Tap + to create your first spiritual reminder',
                      icon: Icons.alarm_add_outlined,
                      action: ElevatedButton.icon(
                        onPressed: () => context.push('/reminders/new'),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Reminder'),
                      ),
                    );
                  }
                  return Column(
                    children: reminders.map((r) => _ReminderCard(reminder: r)).toList(),
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
    final typeIcon = r.isAlarm
        ? Icons.alarm_outlined
        : r.repeat == 'daily'
            ? Icons.repeat
            : r.repeat == 'weekly'
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
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppTheme.navySurface,
            title: const Text('Delete reminder', style: TextStyle(color: AppTheme.textPrimary)),
            content: Text('Delete "${r.title}"?', style: const TextStyle(color: AppTheme.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete', style: TextStyle(color: AppTheme.danger)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) {
        // Grab everything we need BEFORE the card leaves the tree: using this
        // card's context after it is removed is what blanked the screen.
        final messenger = ScaffoldMessenger.of(context);
        final title = r.title;
        // delete() removes the reminder from the list in the same frame.
        ref.read(remindersProvider.notifier).delete(r.id);
        messenger.showSnackBar(SnackBar(content: Text('Deleted "$title"')));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isEnabled ? AppTheme.gold.withValues(alpha: 0.3) : AppTheme.navyOutline,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
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
                      color: isEnabled ? AppTheme.textPrimary : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    r.formattedTime.isNotEmpty ? r.formattedTime : 'Daily',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: isEnabled ? AppTheme.textMuted : AppTheme.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
                  if (r.isAlarm) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Alarm',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentPurple,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.gold),
              onPressed: () => context.push('/reminders/${r.id}'),
              tooltip: 'Edit reminder',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
              tooltip: 'Delete reminder',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final notifier = ref.read(remindersProvider.notifier);
                final ok = await confirmDeleteReminder(context, r.title);
                if (!ok) return;
                notifier.delete(r.id);
                messenger.showSnackBar(SnackBar(content: Text('Deleted "${r.title}"')));
              },
            ),
            Switch(
              value: isEnabled,
              activeThumbColor: AppTheme.gold,
              onChanged: (val) async {
                try {
                  await ref.read(remindersProvider.notifier).toggleEnabled(r.id);
                } catch (e) {
                  ref.invalidate(remindersProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update reminder: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
