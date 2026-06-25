import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/dio_client.dart';
import '../../repositories/prayer_repository.dart';

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

  final _types = ['request', 'praise', 'intercession', 'thanksgiving'];

  @override
  void dispose() {
    _title.dispose(); _content.dispose(); _scripture.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await PrayerRepository().create(
        title: _title.text.trim(),
        content: _content.text.trim(),
        prayerType: _type,
        scripture: _scripture.text.trim(),
      );
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
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              DropdownButtonFormField<String>(
                value: _type,
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
