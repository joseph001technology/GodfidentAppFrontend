import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/dio_client.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

/// Edit name, photo, church, location, favourite verse, phone and bio.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _bio = TextEditingController();
  final _church = TextEditingController();
  final _location = TextEditingController();
  final _verse = TextEditingController();
  final _phone = TextEditingController();
  String _avatarData = '';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = ref.read(currentUserProvider).valueOrNull;
    _first.text = u?.firstName ?? '';
    _last.text = u?.lastName ?? '';
    _bio.text = u?.profile?.bio ?? '';
    _church.text = u?.profile?.church ?? '';
    _location.text = u?.profile?.location ?? '';
    _verse.text = u?.profile?.favoriteVerse ?? '';
    _phone.text = u?.profile?.phone ?? '';
    _avatarData = u?.profile?.avatarData ?? '';
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _bio.dispose();
    _church.dispose();
    _location.dispose();
    _verse.dispose();
    _phone.dispose();
    super.dispose();
  }

  Uint8List? get _photoBytes {
    final i = _avatarData.indexOf('base64,');
    if (i < 0) return null;
    try {
      return base64Decode(_avatarData.substring(i + 7));
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 320, maxHeight: 320, imageQuality: 72);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      final mime = f.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      setState(() => _avatarData = 'data:image/$mime;base64,${base64Encode(bytes)}');
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open your photos.');
    }
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
      await repo.updateProfile({
        'bio': _bio.text.trim(),
        'church': _church.text.trim(),
        'location': _location.text.trim(),
        'favorite_verse': _verse.text.trim(),
        'phone': _phone.text.trim(),
        'avatar_data': _avatarData,
      });
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
        Center(
          child: Column(children: [
            GestureDetector(
              onTap: _pickPhoto,
              child: CircleAvatar(
                radius: 52,
                backgroundColor: AppTheme.gold,
                backgroundImage: _photoBytes != null ? MemoryImage(_photoBytes!) : null,
                child: _photoBytes == null ? const Icon(Icons.add_a_photo_outlined, size: 32, color: AppTheme.inkNavy) : null,
              ),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(onPressed: _pickPhoto, child: Text(_photoBytes == null ? 'Add photo' : 'Change photo')),
              if (_photoBytes != null)
                TextButton(onPressed: () => setState(() => _avatarData = ''), child: const Text('Remove')),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
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
        const SizedBox(height: 8),
        TextField(controller: _church, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'My church', prefixIcon: Icon(Icons.church_outlined))),
        const SizedBox(height: 14),
        TextField(controller: _location, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'City / country', prefixIcon: Icon(Icons.place_outlined))),
        const SizedBox(height: 14),
        TextField(controller: _verse, maxLines: 2, decoration: const InputDecoration(labelText: 'Favourite verse', hintText: 'e.g. Psalm 46:10', prefixIcon: Icon(Icons.menu_book_outlined))),
        const SizedBox(height: 14),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)', prefixIcon: Icon(Icons.phone_outlined))),
        const SizedBox(height: 10),
        Text('Email: $email (cannot be changed here)', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        if (_error != null)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: AppTheme.danger))),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
      ]),
    );
  }
}
