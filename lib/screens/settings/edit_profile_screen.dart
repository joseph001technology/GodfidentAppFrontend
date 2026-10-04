import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/dio_client.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

/// Edit the parts of the profile the server really stores: name and bio.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _bio = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = ref.read(currentUserProvider).valueOrNull;
    _first.text = u?.firstName ?? '';
    _last.text = u?.lastName ?? '';
    _bio.text = u?.profile?.bio ?? '';
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your first name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.updateMe(firstName: _first.text.trim(), lastName: _last.text.trim());
      await repo.updateProfile({'bio': _bio.text.trim()});
      await ref.read(currentUserProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
      context.pop();
    } on DioException catch (e) {
      setState(() => _error = extractError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserProvider).valueOrNull?.email ?? '';
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        TextField(controller: _first, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'First name')),
        const SizedBox(height: 14),
        TextField(controller: _last, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Last name')),
        const SizedBox(height: 14),
        TextField(
          controller: _bio,
          maxLines: 4,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'About me', hintText: 'A verse you hold to, or why you are here'),
        ),
        const SizedBox(height: 6),
        Text('Email: $email (cannot be changed here)', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        if (_error != null)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: AppTheme.danger))),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
      ]),
    );
  }
}
