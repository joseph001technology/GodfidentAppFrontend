import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/reminder.dart';
import '../../services/notification_service.dart';
import '../../services/permissions_service.dart';

/// Plain-language notifications page. Reminders themselves (time, type, sound)
/// are created in the Reminders tab; this page only answers "will my reminders
/// actually reach me?" and lets the user fix whatever Android is blocking.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> with WidgetsBindingObserver {
  List<PermissionItem> _items = const [];
  bool _loading = true;

  static const _ids = ['notifications', 'alarms', 'battery'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final all = await PermissionsService.instance.snapshot();
    if (!mounted) return;
    setState(() {
      _items = all.where((p) => _ids.contains(p.id)).toList();
      _loading = false;
    });
  }

  Future<void> _fix(String id) async {
    await PermissionsService.instance.request(id);
    await _refresh();
  }

  Future<void> _test() async {
    final now = DateTime.now();
    final r = Reminder(
      id: 987654,
      title: 'Test from Godfident',
      description: 'If you can see this, your reminders will reach you.',
      date: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00',
      createdAt: now.toIso8601String(),
    );
    await NotificationService().showNow(r);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test notification sent')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final allOk = _items.isNotEmpty && _items.every((p) => p.granted);
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (allOk ? AppTheme.emerald : AppTheme.gold).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Icon(allOk ? Icons.check_circle : Icons.info_outline, color: allOk ? AppTheme.emerald : AppTheme.goldDark),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                allOk
                    ? 'Everything is set. Your reminders will reach you on time, even when Godfident is closed.'
                    : 'A few switches below need to be allowed so your reminders arrive on time.',
                style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        if (_loading) const Center(child: CircularProgressIndicator(color: AppTheme.gold)),
        for (final p in _items)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.navySurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.navyOutline),
            ),
            child: Row(children: [
              Icon(p.granted ? Icons.check_circle : Icons.error_outline, color: p.granted ? AppTheme.emerald : AppTheme.danger),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(p.why, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35)),
                ]),
              ),
              if (!p.granted)
                TextButton(onPressed: () => _fix(p.id), child: const Text('Allow')),
            ]),
          ),
        const SizedBox(height: 10),
        const Text('How reminders work',
            style: TextStyle(fontFamily: 'Lora', fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const _Help(Icons.alarm_add_outlined, 'Set them in the Reminders tab',
            'Choose a time, a type (Prayer, Reading, Both or Other), how often it repeats and the sound.'),
        const _Help(Icons.touch_app_outlined, 'Tapping a reminder takes you there',
            'Prayer opens a Prayer Focus session. Reading starts Focus and opens the Bible. Both starts Focus on Home. Other opens Reminders.'),
        const _Help(Icons.notifications_active_outlined, 'Notification or alarm',
            'A notification rings once. An alarm keeps ringing until you stop it, like a clock alarm.'),
        const _Help(Icons.flag_outlined, 'End of session',
            'When a Focus or Prayer Focus session finishes, Godfident tells you, even if the app is closed.'),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _test,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('Send a test'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => context.go('/reminders'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold, foregroundColor: AppTheme.inkNavy, minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.alarm, size: 18),
              label: const Text('My reminders'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _Help extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Help(this.icon, this.title, this.body);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: AppTheme.goldDark, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(body, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35)),
            ]),
          ),
        ]),
      );
}
