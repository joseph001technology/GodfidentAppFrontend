import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/scheduled_focus.dart';
import '../../providers/scheduled_focus_provider.dart';
import '../../services/notification_service.dart';
import '../../services/ringtone_store.dart';
import '../../widgets/common/ringtone_picker.dart';

/// Create or edit a pre-set Focus session ("6:00 AM, 30 min, Bible + prayer").
class ScheduleEditorScreen extends ConsumerStatefulWidget {
  final int? scheduleId;
  const ScheduleEditorScreen({super.key, this.scheduleId});
  @override
  ConsumerState<ScheduleEditorScreen> createState() => _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends ConsumerState<ScheduleEditorScreen> {
  final _title = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 6, minute: 0);
  int _minutes = 30;
  String _purpose = 'both';
  final Set<int> _days = {};
  bool _enabled = true;
  Ringtone _ringtone = Ringtone.fallback;
  ScheduledFocus? _existing;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = widget.scheduleId;
    if (id != null) {
      final f = await ref.read(scheduledFocusProvider.notifier).byId(id);
      if (f != null) {
        _existing = f;
        _title.text = f.title;
        _time = TimeOfDay(hour: f.hour, minute: f.minute);
        _minutes = f.durationMinutes;
        _purpose = f.purpose;
        _days
          ..clear()
          ..addAll(f.days);
        _enabled = f.enabled;
        _ringtone = await RingtoneStore.instance.load(NotificationService.focusRingtoneKey(f.id));
      }
    } else {
      _ringtone = await RingtoneStore.instance.load(-1); // falls back to the default tone
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _pickRingtone() async {
    final picked = await showRingtonePicker(
      context,
      current: _ringtone,
      onChanged: (t) {
        if (mounted) setState(() => _ringtone = t); // kept even if the sheet is dismissed
      },
    );
    if (picked != null && mounted) setState(() => _ringtone = picked);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final notifier = ref.read(scheduledFocusProvider.notifier);
    try {
      final id = _existing?.id ?? await notifier.newId();
      final f = ScheduledFocus(
        id: id,
        backendId: _existing?.backendId,
        title: _title.text.trim(),
        purpose: _purpose,
        hour: _time.hour,
        minute: _time.minute,
        durationMinutes: _minutes,
        days: (_days.toList()..sort()),
        enabled: _enabled,
      );
      final ok = await notifier.save(f, ringtone: _ringtone);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _saving = false;
          _error = 'Saved, but Android would not schedule the alarm. Allow notifications and "Alarms & reminders" for Godfident in Settings.';
        });
        return;
      }
      context.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this session. Please try again.';
        });
      }
    }
  }

  Future<void> _delete() async {
    final e = _existing;
    if (e == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this session?'),
        content: const Text('The alarm will be removed from this phone and your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true) return;
    await ref.read(scheduledFocusProvider.notifier).delete(e.id);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: Text(widget.scheduleId == null ? 'New session' : 'Edit session'),
        actions: [
          if (_existing != null)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete', onPressed: _delete),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                _label('Name (optional)'),
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Morning with God'),
                ),
                const SizedBox(height: 20),
                _label('Starts at'),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickTime,
                  child: _box(Row(children: [
                    const Icon(Icons.access_time, color: AppTheme.goldDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_time.format(context),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  ])),
                ),
                const SizedBox(height: 20),
                _label('Duration'),
                Wrap(spacing: 10, runSpacing: 8, children: [
                  for (final m in const [15, 30, 45, 60, 90, 120])
                    ChoiceChip(
                      label: Text(m < 60 ? '$m min' : (m % 60 == 0 ? '${m ~/ 60} hr' : '${m ~/ 60} hr 30')),
                      selected: _minutes == m,
                      selectedColor: AppTheme.gold,
                      labelStyle: TextStyle(
                          color: _minutes == m ? AppTheme.inkNavy : AppTheme.textPrimary, fontWeight: FontWeight.w600),
                      onSelected: (_) => setState(() => _minutes = m),
                    ),
                ]),
                const SizedBox(height: 20),
                _label('This time is for'),
                Wrap(spacing: 10, runSpacing: 8, children: [
                  for (final e in ScheduledFocus.purposes.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _purpose == e.key,
                      selectedColor: AppTheme.gold,
                      labelStyle: TextStyle(
                          color: _purpose == e.key ? AppTheme.inkNavy : AppTheme.textPrimary,
                          fontWeight: FontWeight.w600),
                      onSelected: (_) => setState(() => _purpose = e.key),
                    ),
                ]),
                const SizedBox(height: 20),
                _label(_days.isEmpty ? 'Repeat  ·  once (next time the clock hits)' : 'Repeat'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(ScheduledFocus.dayNames[d - 1]),
                      selected: _days.contains(d),
                      selectedColor: AppTheme.gold,
                      checkmarkColor: AppTheme.inkNavy,
                      labelStyle: TextStyle(
                          color: _days.contains(d) ? AppTheme.inkNavy : AppTheme.textPrimary,
                          fontWeight: FontWeight.w600),
                      onSelected: (on) => setState(() => on ? _days.add(d) : _days.remove(d)),
                    ),
                ]),
                const SizedBox(height: 20),
                _label('Alarm sound'),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickRingtone,
                  child: _box(Row(children: [
                    const Icon(Icons.music_note, color: AppTheme.goldDark),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_ringtone.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                    const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  ])),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.gold,
                  title: const Text('Enabled', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('The phone rings at the start time until you press Start.',
                      style: TextStyle(fontSize: 12)),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: AppTheme.inkNavy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save session'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppTheme.textMuted)),
      );

  Widget _box(Widget child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.navyOutline),
        ),
        child: child,
      );
}
