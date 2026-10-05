import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/reminders_provider.dart';
import '../../core/dio_client.dart';
import '../../services/ringtone_store.dart';
import '../../widgets/common/delete_reminder.dart';
import '../../widgets/common/ringtone_picker.dart';

class ReminderEditorScreen extends ConsumerStatefulWidget {
  final String? reminderId;

  const ReminderEditorScreen({
    super.key,
    this.reminderId,
  });

  @override
  ConsumerState<ReminderEditorScreen> createState() =>
      _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends ConsumerState<ReminderEditorScreen> {
  late TextEditingController titleController;
  late TextEditingController descriptionController;
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();
  int? selectedCategoryId;
  String selectedTarget = 'general';
  String selectedRepeat = 'none';
  bool isEnabled = true;
  bool isAlarmWithRingtone = true;
  Duration snoozeDuration = const Duration(minutes: 5);
  Ringtone _ringtone = Ringtone.fallback;
  bool _saving = false;

  static const repeatOptions = ['none', 'daily', 'weekly', 'monthly'];

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController();
    descriptionController = TextEditingController();
    _loadExisting();
  }

  /// Pre-fills the form when editing (it used to open blank), and picks up the
  /// ringtone saved for this reminder (or the last one used).
  Future<void> _loadExisting() async {
    final id = int.tryParse(widget.reminderId ?? '');
    final tone = await RingtoneStore.instance.load(id ?? 0);
    if (mounted) setState(() => _ringtone = tone);
    if (id == null) return;
    try {
      final r = await ref.read(remindersRepositoryProvider).getDetail(id);
      if (!mounted) return;
      setState(() {
        titleController.text = r.title;
        descriptionController.text = r.description ?? '';
        final dt = r.dateTime;
        if (dt != null) {
          selectedDate = DateTime(dt.year, dt.month, dt.day);
          selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
        }
        selectedRepeat = repeatOptions.contains(r.repeat) ? r.repeat : 'none';
        isEnabled = r.isEnabled;
        isAlarmWithRingtone = r.isAlarm;
        selectedCategoryId = r.category;
        selectedTarget = r.kind;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveReminder() async {
    if (_saving) return; // a second tap must never create a second reminder
    final messenger = ScaffoldMessenger.of(context);
    if (titleController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a reminder title'), backgroundColor: Colors.red),
      );
      return;
    }
    final when = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
    if (selectedRepeat == 'none' && !when.isAfter(DateTime.now())) {
      messenger.showSnackBar(
        const SnackBar(content: Text('That time has already passed. Pick a time in the future.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _saving = true);
    final savedAt = selectedTime.format(context); // read context before any await

    final data = <String, dynamic>{
      'title': titleController.text.trim(),
      'description': descriptionController.text.trim(),
      'date': '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
      'time': '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00',
      'repeat': selectedRepeat,
      'is_enabled': isEnabled,
      'is_alarm': isAlarmWithRingtone,
      if (selectedCategoryId != null) 'category': selectedCategoryId,
      'target_page': selectedTarget,
      'snooze_minutes': snoozeDuration.inMinutes,
    };

    try {
      final notifier = ref.read(remindersProvider.notifier);
      if (widget.reminderId != null) {
        await notifier.update(int.tryParse(widget.reminderId!) ?? 0, data, ringtone: _ringtone);
      } else {
        await notifier.create(data, ringtone: _ringtone);
      }
      final scheduled = notifier.lastScheduleOk;
      messenger.showSnackBar(
        SnackBar(
          content: Text(!isEnabled
              ? 'Saved (reminder is switched off).'
              : scheduled
                  ? 'Saved. You will be reminded at $savedAt.'
                  : 'Saved to your account, but this phone could not schedule the alert. Check Profile \u2192 Permissions.'),
          backgroundColor: scheduled || !isEnabled ? AppTheme.emerald : AppTheme.danger,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Show the REAL reason (server message / network) and let them retry.
      debugPrint('Saving reminder failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteReminder() async {
    final id = int.tryParse(widget.reminderId ?? '');
    if (id == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final notifier = ref.read(remindersProvider.notifier);
    final name = titleController.text.trim().isEmpty ? 'this reminder' : titleController.text.trim();
    final ok = await confirmDeleteReminder(context, name);
    if (!ok) return;
    await notifier.delete(id);
    messenger.showSnackBar(SnackBar(content: Text('Deleted "$name"')));
    nav.pop();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2099),
    );
    if (date != null) {
      setState(() => selectedDate = date);
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (time != null) {
      setState(() => selectedTime = time);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: AppTheme.navy,
        title: Text(
          widget.reminderId != null ? 'Edit Reminder' : 'New Reminder',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (widget.reminderId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
              tooltip: 'Delete reminder',
              onPressed: _saving ? null : _deleteReminder,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: titleController,
              label: 'Reminder Title',
              hint: 'e.g., Morning Prayer',
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: descriptionController,
              label: 'Description',
              hint: 'Add details about this reminder',
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            _buildCategorySelector(),
            const SizedBox(height: 20),
            _buildDateTimeSelector(),
            const SizedBox(height: 20),
            _buildFrequencySelector(),
            const SizedBox(height: 20),
            _buildSnoozeDurationSelector(),
            const SizedBox(height: 20),
            _buildEnabledToggle(),
            const SizedBox(height: 16),
            _buildAlarmToggle(),
            const SizedBox(height: 12),
            _buildRingtoneTile(),
            const SizedBox(height: 32),
            _buildSaveButton(),
            if (widget.reminderId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _deleteReminder,
                  icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                  label: const Text('Delete reminder', style: TextStyle(color: AppTheme.danger)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.danger),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMuted,
            ),
            filled: true,
            fillColor: AppTheme.navySurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  static const _kinds = <(String, String, String, String)>[
    ('prayer', '\u{1F64F}', 'Prayer', 'Tap opens a Prayer Focus session'),
    ('bible', '\u{1F4D6}', 'Reading', 'Tap starts Focus and opens the Bible'),
    ('both', '\u2728', 'Both', 'Tap starts Focus and opens Home'),
    ('general', '\u23F0', 'Other', 'Tap opens your Reminders'),
  ];

  Widget _buildCategorySelector() {
    final current = _kinds.firstWhere((k) => k.$1 == selectedTarget, orElse: () => _kinds.last);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type of reminder',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in _kinds)
              GestureDetector(
                onTap: () => setState(() => selectedTarget = k.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selectedTarget == k.$1 ? AppTheme.emerald : AppTheme.navySurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selectedTarget == k.$1 ? AppTheme.emerald : AppTheme.navyOutline),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(k.$2, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      k.$3,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selectedTarget == k.$1 ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(current.$4, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildDateTimeSelector() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Date',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Time',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectTime,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    selectedTime.format(context),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequency',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: repeatOptions.map((repeat) {
              final isSelected = selectedRepeat == repeat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => selectedRepeat = repeat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.emerald : AppTheme.navySurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      repeat.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSnoozeDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Snooze Duration',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButton<Duration>(
          value: snoozeDuration,
          dropdownColor: AppTheme.navySurface,
          isExpanded: true,
          items: const [
            Duration(minutes: 5),
            Duration(minutes: 10),
            Duration(minutes: 15),
            Duration(minutes: 30),
            Duration(hours: 1),
          ].map((duration) {
            return DropdownMenuItem(
              value: duration,
              child: Text(
                '${duration.inMinutes} minutes',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => snoozeDuration = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildEnabledToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Enable Reminder',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Switch(
          value: isEnabled,
          onChanged: (value) => setState(() => isEnabled = value),
          activeTrackColor: AppTheme.emerald,
          activeThumbColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildAlarmToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alarm with Ringtone ⏰',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Max volume alert with sound & vibration',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        Switch(
          value: isAlarmWithRingtone,
          onChanged: (value) => setState(() => isAlarmWithRingtone = value),
          activeTrackColor: AppTheme.gold,
          activeThumbColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildRingtoneTile() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showRingtonePicker(
          context,
          current: _ringtone,
          onChanged: (t) {
            if (mounted) setState(() => _ringtone = t);
          },
        );
        if (picked != null && mounted) setState(() => _ringtone = picked);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.navyOutline),
        ),
        child: Row(children: [
          const Icon(Icons.music_note, color: AppTheme.goldDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ringtone', style: TextStyle(fontWeight: FontWeight.w600)),
              Text(_ringtone.title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.textMuted),
        ]),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saving ? null : _saveReminder,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.emerald,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          _saving ? 'Saving\u2026' : 'Save Reminder',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
