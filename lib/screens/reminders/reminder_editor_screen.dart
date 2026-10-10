import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/reminders_provider.dart';
import '../../core/dio_client.dart';
import '../../models/reminder.dart';
import '../../services/fasting_log.dart';
import '../../services/notification_service.dart';
import '../../services/ringtone_store.dart';
import '../../widgets/common/christian_art.dart';
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
  /// A specific date is OPTIONAL. Without one, the reminder rings at the next
  /// matching time (or on the chosen weekdays).
  DateTime? pickedDate;
  final Set<int> weekdays = {}; // 1 = Monday ... 7 = Sunday; empty = once
  bool monthly = false;
  String? _art;
  TimeOfDay _askTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay selectedTime = TimeOfDay.now();
  int? selectedCategoryId;
  String selectedTarget = 'general';
  bool isEnabled = true;
  bool isAlarmWithRingtone = true;
  Duration snoozeDuration = const Duration(minutes: 5);
  Ringtone _ringtone = Ringtone.fallback;
  bool _saving = false;


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
    await ArtStore.instance.ensureLoaded();
    final ask = await FastingLog.askTime(id ?? 0);
    if (mounted) {
      setState(() {
        _ringtone = tone;
        _askTime = TimeOfDay(hour: ask.hour, minute: ask.minute);
        if (id != null) _art = ArtStore.instance.of('reminder_$id');
      });
    }
    if (id == null) return;
    try {
      final r = await ref.read(remindersRepositoryProvider).getDetail(id);
      if (!mounted) return;
      setState(() {
        titleController.text = r.title;
        descriptionController.text = r.description ?? '';
        final dt = r.dateTime;
        if (dt != null) selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
        weekdays
          ..clear()
          ..addAll(r.repeat == 'weekly' || r.repeat == 'daily' ? r.weekdays : const <int>[]);
        monthly = r.repeat == 'monthly';
        // A date is only kept when it is a one-off on a future date, or a monthly day.
        if ((r.repeat == 'none' || r.repeat == 'monthly') && dt != null && dt.isAfter(DateTime.now())) {
          pickedDate = DateTime(dt.year, dt.month, dt.day);
        } else if (r.repeat == 'monthly' && dt != null) {
          pickedDate = DateTime(dt.year, dt.month, dt.day);
        }
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
    final now = DateTime.now();
    // What repeats, and which date the server stores (it needs one; the person does not).
    String repeat;
    int? mask;
    DateTime day;
    if (pickedDate != null) {
      day = pickedDate!;
      repeat = monthly ? 'monthly' : 'none';
    } else if (weekdays.length == 7) {
      repeat = 'daily';
      day = DateTime(now.year, now.month, now.day);
    } else if (weekdays.isNotEmpty) {
      repeat = 'weekly';
      mask = Reminder.maskOf(weekdays);
      day = DateTime(now.year, now.month, now.day);
      for (var i = 0; i < 8; i++) {
        final d = DateTime(now.year, now.month, now.day + i, selectedTime.hour, selectedTime.minute);
        if (weekdays.contains(d.weekday) && d.isAfter(now)) {
          day = DateTime(d.year, d.month, d.day);
          break;
        }
      }
    } else {
      repeat = 'none';
      day = DateTime(now.year, now.month, now.day);
      // Rings today if the time is still ahead, otherwise tomorrow.
      if (!DateTime(day.year, day.month, day.day, selectedTime.hour, selectedTime.minute).isAfter(now)) {
        day = day.add(const Duration(days: 1));
      }
    }
    if (pickedDate != null && repeat == 'none' &&
        !DateTime(day.year, day.month, day.day, selectedTime.hour, selectedTime.minute).isAfter(now)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('That time has already passed. Pick a later time or another date.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _saving = true);
    final savedAt = selectedTime.format(context); // read context before any await

    final data = <String, dynamic>{
      'title': titleController.text.trim(),
      'description': descriptionController.text.trim(),
      'date': '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
      'time': '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00',
      'repeat': repeat,
      'repeat_frequency': mask,
      'is_enabled': isEnabled,
      'is_alarm': isAlarmWithRingtone,
      if (selectedCategoryId != null) 'category': selectedCategoryId,
      'target_page': selectedTarget,
      'snooze_minutes': snoozeDuration.inMinutes,
    };

    try {
      final notifier = ref.read(remindersProvider.notifier);
      final existingId = int.tryParse(widget.reminderId ?? '');
      // The fasting question time is saved first so scheduling can use it.
      if (existingId != null) {
        await FastingLog.setAskTime(existingId, _askTime.hour, _askTime.minute);
        await ArtStore.instance.set('reminder_$existingId', _art);
        await notifier.update(existingId, data, ringtone: _ringtone);
      } else {
        await FastingLog.setAskTime(0, _askTime.hour, _askTime.minute); // becomes the default for the new one
        final created = await notifier.create(data, ringtone: _ringtone);
        await FastingLog.setAskTime(created.id, _askTime.hour, _askTime.minute);
        if (_art != null) await ArtStore.instance.set('reminder_${created.id}', _art);
        if (selectedTarget == 'fasting') await NotificationService().scheduleReminder(created);
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
      initialDate: pickedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2099),
    );
    if (date != null) {
      setState(() {
        pickedDate = date;
        weekdays.clear();
      });
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
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
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
            _buildPictureTile(),
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
    ('fasting', '\u{1F33E}', 'Fasting', 'Reminds you to fast, then asks in the evening: did you?'),
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
        Text(current.$4, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _label(String t) => Text(t,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.w500));

  Widget _buildDateTimeSelector() {
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const full = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dateText = pickedDate == null
        ? 'Not needed'
        : '${pickedDate!.year}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}';
    String summary;
    if (pickedDate != null) {
      summary = monthly ? 'Rings every month on day ${pickedDate!.day}.' : 'Rings once, on that date.';
    } else if (weekdays.isEmpty) {
      summary = 'Rings once, the next time ${selectedTime.format(context)} comes around.';
    } else {
      summary = 'Rings ${Reminder.daysLabel(weekdays.toList()).toLowerCase()} at ${selectedTime.format(context)}.';
    }
    Widget quick(String label, List<int> days) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            onPressed: () => setState(() {
              pickedDate = null;
              monthly = false;
              weekdays
                ..clear()
                ..addAll(days);
            }),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Time'),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _selectTime,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(Icons.access_time, color: AppTheme.goldDark),
            const SizedBox(width: 12),
            Text(selectedTime.format(context),
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.ink)),
          ]),
        ),
      ),
      const SizedBox(height: 20),
      _label('Repeat on'),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (var i = 0; i < 7; i++)
          Tooltip(
            message: full[i],
            child: GestureDetector(
              onTap: () => setState(() {
                pickedDate = null;
                monthly = false;
                weekdays.contains(i + 1) ? weekdays.remove(i + 1) : weekdays.add(i + 1);
              }),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: weekdays.contains(i + 1) ? AppTheme.gold : AppTheme.navySurface,
                  border: Border.all(color: weekdays.contains(i + 1) ? AppTheme.gold : AppTheme.navyOutline),
                ),
                child: Text(names[i],
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: weekdays.contains(i + 1) ? AppTheme.inkNavy : AppTheme.textPrimary)),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          quick('Every day', const [1, 2, 3, 4, 5, 6, 7]),
          quick('Weekdays', const [1, 2, 3, 4, 5]),
          quick('Weekends', const [6, 7]),
          quick('Once', const []),
        ]),
      ),
      const SizedBox(height: 14),
      _label('Date (optional)'),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(12)),
              child: Text(dateText,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: pickedDate == null ? AppTheme.textMuted : AppTheme.textPrimary)),
            ),
          ),
        ),
        if (pickedDate != null)
          IconButton(
            tooltip: 'Remove the date',
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              pickedDate = null;
              monthly = false;
            }),
          ),
      ]),
      if (pickedDate != null)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppTheme.gold,
          title: const Text('Repeat every month on this day'),
          value: monthly,
          onChanged: (v) => setState(() => monthly = v),
        ),
      const SizedBox(height: 8),
      Text(summary, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      if (selectedTarget == 'fasting') ...[
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: _askTime);
            if (t != null) setState(() => _askTime = t);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.navySurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.navyOutline),
            ),
            child: Row(children: [
              const Icon(Icons.help_outline, color: AppTheme.goldDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Ask me "Did you fast?" at', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(_askTime.format(context), style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ]),
              ),
              Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ]),
          ),
        ),
      ],
    ]);
  }

  Widget _buildPictureTile() {
    final id = int.tryParse(widget.reminderId ?? '');
    return GestureDetector(
      onTap: () async {
        final c = await showArtPicker(context, current: _art);
        if (c != null) setState(() => _art = c.isEmpty ? null : c);
      },
      child: SizedBox(
        height: 120,
        child: Stack(fit: StackFit.expand, children: [
          ArtImage(ref: _art, fallbackScene: defaultSceneForType(selectedTarget == 'bible' ? 'reading' : selectedTarget)),
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.image_outlined, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(id == null && _art == null ? 'Choose a picture' : 'Change picture',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),
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
              Text(_ringtone.title, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ]),
          ),
          Icon(Icons.chevron_right, color: AppTheme.textMuted),
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
