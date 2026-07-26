import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:godfident/models/reminder.dart';
import 'package:godfident/providers/remaining_providers.dart';
import 'package:godfident/core/theme.dart';

class ReminderEditorScreen extends ConsumerStatefulWidget {
  final String? reminderId;

  const ReminderEditorScreen({
    Key? key,
    this.reminderId,
  }) : super(key: key);

  @override
  ConsumerState<ReminderEditorScreen> createState() =>
      _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends ConsumerState<ReminderEditorScreen> {
  late TextEditingController titleController;
  late TextEditingController descriptionController;
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();
  ReminderCategory selectedCategory = ReminderCategory.prayer;
  ReminderFrequency selectedFrequency = ReminderFrequency.once;
  bool isEnabled = true;
  Duration snoozeDuration = const Duration(minutes: 5);

  final categoryEmojis = {
    ReminderCategory.prayer: '🙏',
    ReminderCategory.bible: '📖',
    ReminderCategory.devotion: '✨',
    ReminderCategory.church: '⛪',
    ReminderCategory.fasting: '🕊️',
    ReminderCategory.sleep: '😴',
    ReminderCategory.water: '💧',
    ReminderCategory.custom: '📌',
  };

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController();
    descriptionController = TextEditingController();
    _loadReminder();
  }

  void _loadReminder() {
    // TODO: Load reminder by ID from repository when backend is ready
    // For now, using defaults
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _saveReminder() {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a reminder title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final reminder = Reminder(
      id: widget.reminderId ?? DateTime.now().toString(),
      title: titleController.text.trim(),
      description: descriptionController.text.trim(),
      category: selectedCategory,
      scheduledTime: DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      ),
      frequency: selectedFrequency,
      isEnabled: isEnabled,
      snoozeDurationMinutes: snoozeDuration.inMinutes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save via provider
    ref.read(remindersProvider.notifier).add(reminder);
    ref.invalidate(upcomingRemindersProvider);
    ref.invalidate(remindersByCategoryProvider(selectedCategory));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reminder saved'),
        backgroundColor: AppTheme.emerald,
      ),
    );

    Navigator.of(context).pop();
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
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: titleController,
              label: 'Reminder Title',
              hint: 'e.g., Morning Prayer',
            ),
            SizedBox(height: 20),
            _buildTextField(
              controller: descriptionController,
              label: 'Description',
              hint: 'Add details about this reminder',
              maxLines: 3,
            ),
            SizedBox(height: 20),
            _buildCategorySelector(),
            SizedBox(height: 20),
            _buildDateTimeSelector(),
            SizedBox(height: 20),
            _buildFrequencySelector(),
            SizedBox(height: 20),
            _buildSnoozeDurationSelector(),
            SizedBox(height: 20),
            _buildEnabledToggle(),
            SizedBox(height: 32),
            _buildSaveButton(),
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
            color: AppTheme.warmGray,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.warmGray.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: AppTheme.navySurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.warmGray,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ReminderCategory.values.map((category) {
            final isSelected = selectedCategory == category;
            return GestureDetector(
              onTap: () => setState(() => selectedCategory = category),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.emerald : AppTheme.navySurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppTheme.emerald : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      categoryEmojis[category] ?? '📌',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(width: 4),
                    Text(
                      category.name.replaceAll('_', ' ').toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isSelected ? Colors.white : AppTheme.warmGray,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
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
                  color: AppTheme.warmGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Time',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.warmGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              GestureDetector(
                onTap: _selectTime,
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    selectedTime.format(context),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
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
            color: AppTheme.warmGray,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ReminderFrequency.values.map((frequency) {
              final isSelected = selectedFrequency == frequency;
              return Padding(
                padding: EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => selectedFrequency = frequency),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.emerald : AppTheme.navySurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      frequency.name.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isSelected ? Colors.white : AppTheme.warmGray,
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
            color: AppTheme.warmGray,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 12),
        DropdownButton<Duration>(
          value: snoozeDuration,
          dropdownColor: AppTheme.navySurface,
          isExpanded: true,
          items: [
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
                  color: Colors.white,
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
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        Switch(
          value: isEnabled,
          onChanged: (value) => setState(() => isEnabled = value),
          activeColor: AppTheme.emerald,
          activeThumbColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveReminder,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.emerald,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Save Reminder',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
