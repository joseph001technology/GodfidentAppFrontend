import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/design_utils.dart';
import '../../models/reminder.dart';
import '../../providers/remaining_providers.dart';
import '../../widgets/premium_components.dart';

// ══════════════════════════════════════════════════════════════════════════
// REMINDERS SCREEN
// ══════════════════════════════════════════════════════════════════════════

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateReminderDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e'),
        ),
        data: (reminders) => _buildRemindersList(context, ref, reminders),
      ),
    );
  }

  Widget _buildRemindersList(BuildContext context, WidgetRef ref, List<Reminder> reminders) {
    if (reminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '⏰',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: DesignUtils.spacingLg),
            Text(
              'No reminders yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: DesignUtils.spacingSm),
            Text(
              'Create reminders to stay on track with your spiritual journey',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignUtils.spacingLg),
            ElevatedButton(
              onPressed: () => _showCreateReminderDialog(context, ref),
              child: const Text('Create First Reminder'),
            ),
          ],
        ),
      );
    }

    // Separate active and inactive reminders
    final activeReminders = reminders.where((r) => r.isActive).toList();
    final inactiveReminders = reminders.where((r) => !r.isActive).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(DesignUtils.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Reminders
            if (activeReminders.isNotEmpty) ...[
              Text(
                'Active Reminders',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: DesignUtils.spacingMd),
              ...activeReminders.map((reminder) => _buildReminderCard(context, ref, reminder)),
              const SizedBox(height: DesignUtils.spacingXl),
            ],

            // Inactive Reminders
            if (inactiveReminders.isNotEmpty) ...[
              Text(
                'Inactive Reminders',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: DesignUtils.spacingMd),
              ...inactiveReminders.map((reminder) => _buildReminderCard(context, ref, reminder)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, WidgetRef ref, Reminder reminder) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignUtils.spacingMd),
      child: PremiumCard(
        padding: const EdgeInsets.all(DesignUtils.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.navySurface,
                    borderRadius: DesignUtils.mediumRadius,
                  ),
                  child: Center(
                    child: Text(
                      reminder.categoryEmoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: DesignUtils.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: DesignUtils.spacingXs),
                      Text(
                        '${reminder.formattedTime} • ${reminder.frequencyLabel}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => ref.read(remindersProvider.notifier).toggleReminder(reminder.id),
                  child: Container(
                    width: 50,
                    height: 28,
                    decoration: BoxDecoration(
                      color: reminder.isEnabled ? AppTheme.gold : AppTheme.navySurface,
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                      border: Border.all(
                        color: reminder.isEnabled ? AppTheme.gold : AppTheme.navyOutline,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppTheme.navySurface,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (reminder.description.isNotEmpty) ...[
              const SizedBox(height: DesignUtils.spacingMd),
              Text(
                reminder.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
            const SizedBox(height: DesignUtils.spacingMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignUtils.spacingMd,
                    vertical: DesignUtils.spacingSm,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurface,
                    borderRadius: DesignUtils.smallRadius,
                  ),
                  child: Text(
                    reminder.categoryLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.softBlue,
                        ),
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          ref.read(remindersProvider.notifier).snooze(reminder.id, const Duration(minutes: 5)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: DesignUtils.spacingSm),
                        child: Icon(
                          Icons.snooze_outlined,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => ref.read(remindersProvider.notifier).deleteReminder(reminder.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: DesignUtils.spacingSm),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateReminderDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    var selectedCategory = ReminderCategory.custom;
    var selectedFrequency = ReminderFrequency.daily;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Reminder'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  hintText: 'Reminder title',
                  label: Text('Title'),
                ),
              ),
              const SizedBox(height: DesignUtils.spacingMd),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  hintText: 'Description (optional)',
                  label: Text('Description'),
                ),
              ),
              const SizedBox(height: DesignUtils.spacingMd),
              DropdownButton<ReminderCategory>(
                value: selectedCategory,
                isExpanded: true,
                items: ReminderCategory.values
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat.toString().split('.').last),
                        ))
                    .toList(),
                onChanged: (cat) {
                  if (cat != null) selectedCategory = cat;
                },
              ),
              const SizedBox(height: DesignUtils.spacingMd),
              DropdownButton<ReminderFrequency>(
                value: selectedFrequency,
                isExpanded: true,
                items: ReminderFrequency.values
                    .map((freq) => DropdownMenuItem(
                          value: freq,
                          child: Text(freq.toString().split('.').last),
                        ))
                    .toList(),
                onChanged: (freq) {
                  if (freq != null) selectedFrequency = freq;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Create reminder
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
