import '../models/reminder.dart';
import 'package:uuid/uuid.dart';

// ══════════════════════════════════════════════════════════════════════════
// REMINDERS REPOSITORY
// ══════════════════════════════════════════════════════════════════════════

abstract class RemindersRepository {
  Future<List<Reminder>> getAllReminders();
  Future<List<Reminder>> getActiveReminders();
  Future<List<Reminder>> getRemindersByCategory(ReminderCategory category);
  Future<Reminder?> getReminder(String reminderId);
  Future<List<Reminder>> getUpcomingReminders(Duration within);
  Future<List<Reminder>> getReminderHistory(String reminderId);
  
  Future<Reminder> createReminder({
    required String title,
    String description = '',
    ReminderCategory category = ReminderCategory.custom,
    required DateTime scheduledTime,
    ReminderFrequency frequency = ReminderFrequency.daily,
    DateTime? repeatUntil,
    List<int> daysOfWeek = const [],
    bool repeatUntilCompleted = false,
    int snoozeDurationMinutes = 5,
  });
  
  Future<void> updateReminder(Reminder reminder);
  Future<void> deleteReminder(String reminderId);
  Future<void> toggleReminder(String reminderId);
  Future<void> snoozeReminder(String reminderId, Duration duration);
  Future<void> markReminderAsCompleted(String reminderId);
  Future<void> markReminderAsSkipped(String reminderId);
  Future<void> sendReminder(String reminderId); // Trigger notification
  Future<void> scheduleNextReminder(String reminderId);
}

// ══════════════════════════════════════════════════════════════════════════
// LOCAL REMINDERS REPOSITORY
// ══════════════════════════════════════════════════════════════════════════

class LocalRemindersRepository implements RemindersRepository {
  final Map<String, Reminder> _reminders = {};
  final Map<String, List<DateTime>> _history = {}; // reminderId -> sent times
  static const _uuid = Uuid();

  @override
  Future<List<Reminder>> getAllReminders() async {
    return _reminders.values.toList();
  }

  @override
  Future<List<Reminder>> getActiveReminders() async {
    return _reminders.values.where((r) => r.isActive).toList();
  }

  @override
  Future<List<Reminder>> getRemindersByCategory(ReminderCategory category) async {
    return _reminders.values.where((r) => r.category == category).toList();
  }

  @override
  Future<Reminder?> getReminder(String reminderId) async {
    return _reminders[reminderId];
  }

  @override
  Future<List<Reminder>> getUpcomingReminders(Duration within) async {
    final now = DateTime.now();
    final cutoff = now.add(within);
    return _reminders.values
        .where((r) =>
            r.isActive &&
            r.scheduledTime.isAfter(now) &&
            r.scheduledTime.isBefore(cutoff))
        .toList();
  }

  @override
  Future<List<Reminder>> getReminderHistory(String reminderId) async {
    final times = _history[reminderId] ?? [];
    return times.map((_) => _reminders[reminderId]!).toList();
  }

  @override
  Future<Reminder> createReminder({
    required String title,
    String description = '',
    ReminderCategory category = ReminderCategory.custom,
    required DateTime scheduledTime,
    ReminderFrequency frequency = ReminderFrequency.daily,
    DateTime? repeatUntil,
    List<int> daysOfWeek = const [],
    bool repeatUntilCompleted = false,
    int snoozeDurationMinutes = 5,
  }) async {
    final reminder = Reminder(
      id: _uuid.v4(),
      title: title,
      description: description,
      category: category,
      scheduledTime: scheduledTime,
      frequency: frequency,
      repeatUntil: repeatUntil,
      daysOfWeek: daysOfWeek,
      repeatUntilCompleted: repeatUntilCompleted,
      snoozeDurationMinutes: snoozeDurationMinutes,
    );
    _reminders[reminder.id] = reminder;
    _history[reminder.id] = [];
    // TODO: Save to local storage
    // TODO: Schedule notification via platform
    return reminder;
  }

  @override
  Future<void> updateReminder(Reminder reminder) async {
    _reminders[reminder.id] = reminder;
    // TODO: Save to local storage
    // TODO: Reschedule notification via platform
  }

  @override
  Future<void> deleteReminder(String reminderId) async {
    _reminders.remove(reminderId);
    _history.remove(reminderId);
    // TODO: Save to local storage
    // TODO: Cancel notification via platform
  }

  @override
  Future<void> toggleReminder(String reminderId) async {
    if (_reminders.containsKey(reminderId)) {
      final reminder = _reminders[reminderId]!;
      _reminders[reminderId] = reminder.copyWith(isEnabled: !reminder.isEnabled);
      // TODO: Save to local storage
      // TODO: Update notification via platform
    }
  }

  @override
  Future<void> snoozeReminder(String reminderId, Duration duration) async {
    if (_reminders.containsKey(reminderId)) {
      final reminder = _reminders[reminderId]!;
      final newTime = DateTime.now().add(duration);
      _reminders[reminderId] = reminder.copyWith(
        scheduledTime: newTime,
        lastSentAt: DateTime.now(),
      );
      // TODO: Save to local storage
      // TODO: Reschedule notification via platform
    }
  }

  @override
  Future<void> markReminderAsCompleted(String reminderId) async {
    if (_reminders.containsKey(reminderId)) {
      final reminder = _reminders[reminderId]!;
      _reminders[reminderId] = reminder.copyWith(
        completionCount: reminder.completionCount + 1,
        lastSentAt: DateTime.now(),
      );
      _history[reminderId]?.add(DateTime.now());
      // TODO: Save to local storage
    }
  }

  @override
  Future<void> markReminderAsSkipped(String reminderId) async {
    // Record skip but don't complete
    _history[reminderId]?.add(DateTime.now());
    // TODO: Save to local storage
  }

  @override
  Future<void> sendReminder(String reminderId) async {
    if (_reminders.containsKey(reminderId)) {
      final reminder = _reminders[reminderId]!;
      _reminders[reminderId] = reminder.copyWith(lastSentAt: DateTime.now());
      // TODO: Show notification via platform
      // TODO: Save to local storage
    }
  }

  @override
  Future<void> scheduleNextReminder(String reminderId) async {
    if (_reminders.containsKey(reminderId)) {
      final reminder = _reminders[reminderId]!;
      DateTime nextTime;

      switch (reminder.frequency) {
        case ReminderFrequency.once:
          // Don't reschedule
          return;
        case ReminderFrequency.daily:
          nextTime = reminder.scheduledTime.add(const Duration(days: 1));
          break;
        case ReminderFrequency.weekly:
          nextTime = reminder.scheduledTime.add(const Duration(days: 7));
          break;
        case ReminderFrequency.monthly:
          nextTime = DateTime(
            reminder.scheduledTime.year,
            reminder.scheduledTime.month + 1,
            reminder.scheduledTime.day,
            reminder.scheduledTime.hour,
            reminder.scheduledTime.minute,
          );
          break;
        case ReminderFrequency.custom:
          // Custom logic handled elsewhere
          return;
      }

      // Check if should stop repeating
      if (reminder.repeatUntil != null && nextTime.isAfter(reminder.repeatUntil!)) {
        return;
      }

      _reminders[reminderId] = reminder.copyWith(scheduledTime: nextTime);
      // TODO: Save to local storage
      // TODO: Schedule next notification via platform
    }
  }
}
