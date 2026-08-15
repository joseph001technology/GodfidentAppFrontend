import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../services/notification_service.dart';
import '../../models/reminder.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  final Map<String, Map<String, dynamic>> _settings = {};
  final List<Map<String, String>> _types = [
    {'key': 'prayer', 'label': 'Prayer reminders'},
    {'key': 'bible', 'label': 'Bible reminders'},
    {'key': 'reading', 'label': 'Reading reminders'},
    {'key': 'habit', 'label': 'Habit reminders'},
    {'key': 'devotional', 'label': 'Devotionals'},
    {'key': 'daily_verse', 'label': 'Daily verse'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('notification_settings') ?? '{}';
    final map = jsonDecode(raw) as Map<String, dynamic>;
    for (final t in _types) {
      final key = t['key']!;
      final value = map[key] as Map<String, dynamic>?;
      _settings[key] = {
        'enabled': value?['enabled'] ?? false,
        'hour': value?['hour'] ?? 7,
        'minute': value?['minute'] ?? 0,
        'repeat': value?['repeat'] ?? 'daily',
        'mode': value?['mode'] ?? 'notification',
      };
    }
    setState(() {});
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, dynamic>{};
    _settings.forEach((k, v) => out[k] = v);
    await prefs.setString('notification_settings', jsonEncode(out));
  }

  Future<void> _applySetting(String key) async {
    final s = _settings[key]!;
    final enabled = s['enabled'] as bool;
    final hour = s['hour'] as int;
    final minute = s['minute'] as int;
    final repeat = s['repeat'] as String;
    final mode = s['mode'] as String;

    // Create a lightweight Reminder object to schedule
    final now = DateTime.now();
    final scheduleDate = DateTime(now.year, now.month, now.day, hour, minute);
    final rid = key.hashCode & 0x7FFFFFFF; // positive id

    final reminder = Reminder(
      id: rid,
      title: _types.firstWhere((t) => t['key'] == key)['label']!,
      description: 'Auto reminder',
      date: '${scheduleDate.year}-${scheduleDate.month.toString().padLeft(2, '0')}-${scheduleDate.day.toString().padLeft(2, '0')}',
      time: '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00',
      createdAt: DateTime.now().toIso8601String(),
    );

    final notif = NotificationService();
    if (enabled) {
      if (mode == 'alarm') {
        await notif.scheduleAlarm(reminder);
      } else {
        await notif.scheduleReminder(reminder);
      }
    } else {
      await notif.cancelReminder(rid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Notification Settings', style: TextStyle(fontFamily: 'Lora', fontSize: 22, color: AppTheme.textPrimary)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _types.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final t = _types[i];
          final key = t['key']!;
          final s = _settings[key] ?? {'enabled': false, 'hour': 7, 'minute': 0, 'repeat': 'daily', 'mode': 'notification'};
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.navySurface, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t['label']!, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Text('${(s['hour'] as int).toString().padLeft(2, '0')}:${(s['minute'] as int).toString().padLeft(2, '0')} · ${s['repeat']}', style: const TextStyle(color: AppTheme.textMuted)),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppTheme.textMuted),
                  onPressed: () async {
                    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _editDialog(context, key));
                    if (result != null) {
                      _settings[key] = result;
                      await _save();
                      await _applySetting(key);
                      setState(() {});
                    }
                  },
                ),
                Switch(
                  value: s['enabled'] as bool,
                  onChanged: (v) async {
                    _settings[key] = {...s, 'enabled': v};
                    await _save();
                    await _applySetting(key);
                    setState(() {});
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _editDialog(BuildContext context, String key) {
    final s = Map<String, dynamic>.from(_settings[key] ?? {'enabled': false, 'hour': 7, 'minute': 0, 'repeat': 'daily', 'mode': 'notification'});
    TimeOfDay selected = TimeOfDay(hour: s['hour'] as int, minute: s['minute'] as int);
    String repeat = s['repeat'] as String;
    String mode = s['mode'] as String;

    return AlertDialog(
      backgroundColor: AppTheme.navySurface,
      title: const Text('Edit Reminder', style: TextStyle(color: AppTheme.textPrimary)),
      content: StatefulBuilder(builder: (context, st) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.access_time, color: AppTheme.textMuted),
              title: Text('Time: ${selected.format(context)}', style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: selected);
                if (t != null) st(() => selected = t);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: repeat,
              items: const [
                DropdownMenuItem(value: 'none', child: Text('None')),
                DropdownMenuItem(value: 'daily', child: Text('Daily')),
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              ],
              onChanged: (v) => st(() => repeat = v ?? 'daily'),
              decoration: const InputDecoration(labelText: 'Repeat'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: mode,
              items: const [
                DropdownMenuItem(value: 'notification', child: Text('Notification')),
                DropdownMenuItem(value: 'alarm', child: Text('Alarm')),
              ],
              onChanged: (v) => st(() => mode = v ?? 'notification'),
              decoration: const InputDecoration(labelText: 'Mode'),
            ),
          ],
        );
      }),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () {
          _settings[key] = {'enabled': true, 'hour': selected.hour, 'minute': selected.minute, 'repeat': repeat, 'mode': mode};
          Navigator.pop(context, _settings[key]);
        }, child: const Text('Save')),
      ],
    );
  }
}
