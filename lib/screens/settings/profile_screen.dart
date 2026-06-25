import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/common/app_widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _firstName = TextEditingController();
  final _lastName  = TextEditingController();
  String _translation = 'KJV';
  bool _readingReminder = true;
  bool _prayerReminder  = true;
  bool _loading = false;
  bool _initialised = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  void _init(user) {
    if (_initialised || user == null) return;
    _initialised = true;
    _firstName.text = user.firstName;
    _lastName.text  = user.lastName;
    _translation    = user.profile?.preferredTranslation ?? 'KJV';
    _readingReminder = user.profile?.readingReminder ?? true;
    _prayerReminder  = user.profile?.prayerReminder ?? true;
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await AuthRepository().updateMe(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
      );
      await AuthRepository().updateProfile({
        'preferred_translation': _translation,
        'reading_reminder': _readingReminder,
        'prayer_reminder': _prayerReminder,
      });
      await ref.read(currentUserProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated!')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: userAsync.when(
        loading: () => const ShimmerList(count: 5),
        error: (_, __) => const ErrorView(message: 'Could not load profile'),
        data: (user) {
          _init(user);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Avatar
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.gold.withOpacity(0.2),
                  child: Text(
                    user?.initials ?? 'G',
                    style: const TextStyle(color: AppTheme.gold, fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(children: [
                Expanded(child: TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: 'First Name'),
                  textInputAction: TextInputAction.next,
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  textInputAction: TextInputAction.next,
                )),
              ]),
              const SizedBox(height: 14),

              // Email (read-only)
              TextFormField(
                initialValue: user?.email ?? '',
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  suffixIcon: Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                ),
              ),
              const GoldDivider(),

              // Translation picker
              DropdownButtonFormField<String>(
                value: _translation,
                decoration: const InputDecoration(
                  labelText: 'Preferred Translation',
                  prefixIcon: Icon(Icons.translate, color: AppTheme.gold),
                ),
                items: ['KJV', 'NIV', 'ESV', 'NKJV', 'NLT']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _translation = v!),
              ),
              const SizedBox(height: 14),

              // Notification toggles
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Reading Reminders'),
                      value: _readingReminder,
                      activeColor: AppTheme.gold,
                      onChanged: (v) => setState(() => _readingReminder = v),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Prayer Reminders'),
                      value: _prayerReminder,
                      activeColor: AppTheme.gold,
                      onChanged: (v) => setState(() => _prayerReminder = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }
}
