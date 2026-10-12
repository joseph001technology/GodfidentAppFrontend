import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/dio_client.dart';
import '../../repositories/prayer_repository.dart';
import '../../services/notification_service.dart';
import '../../services/prayer_notifications.dart';
import 'prayer_reminders_sheet.dart';

class PrayerFormScreen extends ConsumerStatefulWidget {
  final int? prayerId;
  const PrayerFormScreen({super.key, this.prayerId});

  @override
  ConsumerState<PrayerFormScreen> createState() => _PrayerFormScreenState();
}

class _PrayerFormScreenState extends ConsumerState<PrayerFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title   = TextEditingController();
  final _content = TextEditingController();
  final _scripture = TextEditingController();
  String _type = 'request';
  bool _loading = false;
  String? _error;
  final _reminder = PrayerReminderDraft();

  final _types = ['request', 'praise', 'intercession', 'thanksgiving'];

  @override
  void initState() {
    super.initState();
    final id = widget.prayerId;
    if (id != null) _loadExisting(id);
  }

  /// Edit mode: fill the form with the saved prayer and its reminder.
  Future<void> _loadExisting(int id) async {
    try {
      final p = await PrayerRepository().getDetail(id);
      final r = await PrayerNotifications.getPrayerReminder(id);
      if (!mounted) return;
      setState(() {
        _title.text = p.title;
        _content.text = p.content;
        _scripture.text = p.scripture;
        if (_types.contains(p.prayerType)) _type = p.prayerType;
        if (r != null) {
          final d = PrayerReminderDraft.fromSetting(r);
          _reminder.on = d.on;
          _reminder.time = d.time;
          _reminder.weekly = d.weekly;
          _reminder.weekday = d.weekday;
          _reminder.ring = d.ring;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load this prayer. Check your connection and try again.');
    }
  }

  @override
  void dispose() {
    _title.dispose(); _content.dispose(); _scripture.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final repo = PrayerRepository();
      final title = _title.text.trim();
      final int prayerId;
      if (widget.prayerId == null) {
        final created = await repo.create(
          title: title,
          content: _content.text.trim(),
          prayerType: _type,
          scripture: _scripture.text.trim(),
          reminderEnabled: _reminder.on,
        );
        prayerId = created.id;
      } else {
        await repo.update(widget.prayerId!, {
          'title': title,
          'content': _content.text.trim(),
          'prayer_type': _type,
          'scripture': _scripture.text.trim(),
          'reminder_enabled': _reminder.on,
        });
        prayerId = widget.prayerId!;
      }
      // "Remind me to pray for this": a phone alarm, so it works offline.
      if (_reminder.on) {
        await NotificationService().ensureReminderPermissions();
        await PrayerNotifications.setPrayerReminder(_reminder.toSetting(prayerId, title));
      } else {
        await PrayerNotifications.clearPrayerReminder(prayerId);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() => _error = extractError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.prayerId == null ? 'New Prayer' : 'Edit Prayer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _types.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t[0].toUpperCase() + t.substring(1)),
                )).toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.isEmpty) ? 'Title is required' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _content,
                decoration: const InputDecoration(labelText: 'Prayer', alignLabelWithHint: true),
                maxLines: 5,
                validator: (v) => (v == null || v.isEmpty) ? 'Prayer content is required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _scripture,
                decoration: const InputDecoration(
                  labelText: 'Scripture (optional)',
                  hintText: 'e.g. Philippians 4:6',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 18),
              PrayerReminderPicker(draft: _reminder, onChanged: () => setState(() {})),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Prayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
