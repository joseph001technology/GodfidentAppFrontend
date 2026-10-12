import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/notification_service.dart';
import '../../services/prayer_notifications.dart';

/// Opens the "Prayer reminders" sheet (daily prayer times). Reachable from the
/// prayer hub, Home and the notification settings screens.
Future<void> showPrayerRemindersSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.navySurface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => const _PrayerRemindersSheet(),
  );
}

/// Values of the "Remind me to pray for this" section of the prayer form.
class PrayerReminderDraft {
  bool on;
  TimeOfDay time;
  bool weekly;
  int weekday;
  bool ring;

  PrayerReminderDraft({
    this.on = false,
    this.time = const TimeOfDay(hour: 8, minute: 0),
    this.weekly = false,
    this.weekday = 1,
    this.ring = false,
  });

  factory PrayerReminderDraft.fromSetting(PrayerReminderSetting s) => PrayerReminderDraft(
        on: true,
        time: TimeOfDay(hour: s.hour, minute: s.minute),
        weekly: s.weekly,
        weekday: s.weekday,
        ring: s.ring,
      );

  PrayerReminderSetting toSetting(int prayerId, String title) => PrayerReminderSetting(
        prayerId: prayerId,
        title: title,
        hour: time.hour,
        minute: time.minute,
        weekly: weekly,
        weekday: weekday,
        ring: ring,
      );
}

/// "Remind me to pray for this": time, daily / weekly and ring style. The parent
/// owns the [draft] and rebuilds on [onChanged].
class PrayerReminderPicker extends StatelessWidget {
  final PrayerReminderDraft draft;
  final VoidCallback onChanged;
  const PrayerReminderPicker({super.key, required this.draft, required this.onChanged});

  Future<void> _pickTime(BuildContext context) async {
    final t = await showTimePicker(context: context, initialTime: draft.time);
    if (t == null) return;
    draft.time = t;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.navyOutline),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppTheme.gold,
          secondary: const Icon(Icons.notifications_active_outlined, color: AppTheme.goldDark),
          title: const Text('Remind me to pray for this', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Works offline, even when Godfident is closed.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          value: draft.on,
          onChanged: (v) {
            draft.on = v;
            onChanged();
          },
        ),
        if (draft.on) ...[
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickTime(context),
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(draft.time.format(context)),
              ),
            ),
            const SizedBox(width: 10),
            ChoiceChip(
              label: const Text('Daily'),
              selected: !draft.weekly,
              selectedColor: AppTheme.gold,
              labelStyle: TextStyle(color: !draft.weekly ? AppTheme.inkNavy : AppTheme.textPrimary, fontWeight: FontWeight.w600),
              onSelected: (_) {
                draft.weekly = false;
                onChanged();
              },
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: const Text('Weekly'),
              selected: draft.weekly,
              selectedColor: AppTheme.gold,
              labelStyle: TextStyle(color: draft.weekly ? AppTheme.inkNavy : AppTheme.textPrimary, fontWeight: FontWeight.w600),
              onSelected: (_) {
                draft.weekly = true;
                onChanged();
              },
            ),
          ]),
          if (draft.weekly) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 1; i <= 7; i++)
                ChoiceChip(
                  label: Text(days[i - 1]),
                  selected: draft.weekday == i,
                  selectedColor: AppTheme.gold,
                  labelStyle: TextStyle(
                      color: draft.weekday == i ? AppTheme.inkNavy : AppTheme.textPrimary, fontWeight: FontWeight.w600),
                  onSelected: (_) {
                    draft.weekday = i;
                    onChanged();
                  },
                ),
            ]),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppTheme.gold,
            title: const Text('Ring like an alarm', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Off: a quiet notification.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            value: draft.ring,
            onChanged: (v) {
              draft.ring = v;
              onChanged();
            },
          ),
        ],
      ]),
    );
  }
}

class _PrayerRemindersSheet extends StatefulWidget {
  const _PrayerRemindersSheet();
  @override
  State<_PrayerRemindersSheet> createState() => _PrayerRemindersSheetState();
}

class _PrayerRemindersSheetState extends State<_PrayerRemindersSheet> {
  DailyPrayerSettings? _s;
  int _requestReminders = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await PrayerNotifications.loadDaily();
    final r = await PrayerNotifications.allPrayerReminders();
    if (!mounted) return;
    setState(() {
      _s = s;
      _requestReminders = r.length;
    });
  }

  Future<void> _save(DailyPrayerSettings s) async {
    setState(() => _s = s);
    if (s.anyOn) await NotificationService().ensureReminderPermissions();
    await PrayerNotifications.saveDaily(s);
  }

  Future<void> _pick(int i) async {
    final cur = _s!.slots[i];
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur.hour, minute: cur.minute));
    if (t == null) return;
    final slots = List<DailyPrayerSlot>.from(_s!.slots);
    slots[i] = cur.copyWith(on: true, hour: t.hour, minute: t.minute);
    await _save(_s!.copyWith(slots: slots));
  }

  Future<void> _toggle(int i, bool v) async {
    final slots = List<DailyPrayerSlot>.from(_s!.slots);
    slots[i] = slots[i].copyWith(on: v);
    await _save(_s!.copyWith(slots: slots));
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: s == null
            ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: AppTheme.gold)))
            : SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Prayer reminders',
                      style: TextStyle(fontFamily: 'Lora', fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Choose up to three times a day to meet with God. Tapping a reminder opens Prayer Focus.',
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.textSecondary)),
                  const SizedBox(height: 10),
                  for (var i = 0; i < s.slots.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        i == 0 ? Icons.wb_twilight : (i == 1 ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined),
                        color: AppTheme.goldDark,
                      ),
                      title: Text('${PrayerNotifications.slotNames[i]} prayer', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: GestureDetector(
                        onTap: () => _pick(i),
                        child: Text(
                          'Every day at ${TimeOfDay(hour: s.slots[i].hour, minute: s.slots[i].minute).format(context)}  ·  tap to change',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ),
                      onTap: () => _pick(i),
                      trailing: Switch(
                        value: s.slots[i].on,
                        activeThumbColor: AppTheme.gold,
                        onChanged: (v) => _toggle(i, v),
                      ),
                    ),
                  const Divider(height: 22),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppTheme.gold,
                    title: const Text('Ring like an alarm', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Off: a quiet notification.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    value: s.ring,
                    onChanged: (v) => _save(s.copyWith(ring: v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppTheme.gold,
                    title: const Text("Only if I haven't prayed today", style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Stays silent once you have prayed.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    value: s.onlyIfNotPrayed,
                    onChanged: (v) => _save(s.copyWith(onlyIfNotPrayed: v)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _requestReminders == 0
                        ? 'You can also add a reminder to a single prayer request when you create or edit it.'
                        : '$_requestReminders prayer request${_requestReminders == 1 ? ' has' : 's have'} its own reminder.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ]),
              ),
      ),
    );
  }
}
