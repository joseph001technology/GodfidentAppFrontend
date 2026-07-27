import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/reminders_provider.dart';
import '../../core/theme.dart';

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
  String selectedRepeat = 'none';
  bool isEnabled = true;
  Duration snoozeDuration = const Duration(minutes: 5);

  static const repeatOptions = ['none', 'daily', 'weekly', 'monthly'];

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController();
    descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveReminder() async {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a reminder title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final data = <String, dynamic>{
      'title': titleController.text.trim(),
      if (descriptionController.text.trim().isNotEmpty) 'description': descriptionController.text.trim(),
      'date': '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
      'time': '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00',
      'repeat': selectedRepeat,
      if (selectedCategoryId != null) 'category': selectedCategoryId,
      'snooze_minutes': snoozeDuration.inMinutes,
    };

    if (widget.reminderId != null) {
      final id = int.tryParse(widget.reminderId!) ?? 0;
      await ref.read(remindersProvider.notifier).update(id, data);
    } else {
      await ref.read(remindersProvider.notifier).create(data);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder saved'),
          backgroundColor: AppTheme.emerald,
        ),
      );
      Navigator.of(context).pop();
    }
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
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
            const SizedBox(height: 32),
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
        const SizedBox(height: 8),
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
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    final categoriesAsync = ref.watch(reminderCategoriesProvider);

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
        const SizedBox(height: 12),
        categoriesAsync.when(
          data: (categories) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((category) {
              final isSelected = selectedCategoryId == category.id;
              return GestureDetector(
                onTap: () => setState(() => selectedCategoryId = isSelected ? null : category.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        category.icon ?? '📌',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        category.name.toUpperCase(),
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
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('Could not load categories', style: TextStyle(color: AppTheme.warmGray)),
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
                      color: Colors.white,
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
                  color: AppTheme.warmGray,
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
          activeTrackColor: AppTheme.emerald,
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
          padding: const EdgeInsets.symmetric(vertical: 16),
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
