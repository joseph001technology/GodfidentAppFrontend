import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/permissions_service.dart';

/// Every permission Godfident needs, its real current state, and a button that
/// takes the user to the exact Android screen. Re-checks when they come back.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});
  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  List<PermissionItem>? _items;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load(); // back from Android settings
  }

  Future<void> _load() async {
    final items = await PermissionsService.instance.snapshot();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _ask(PermissionItem p) async {
    if (p.id == 'accessibility') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Turn on Godfident Focus'),
          content: const Text(
            'Godfident uses Android\u2019s Accessibility service ONLY to detect which app has just opened, so it can send you Home when you open an app you chose to block.\n\n'
            'It cannot read your screen, your messages or anything you type.\n\n'
            'On the next screen: Installed apps (or Downloaded apps) \u2192 Godfident Focus \u2192 switch it on.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Continue')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await PermissionsService.instance.request(p.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: const Text('Permissions'),
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.inkNavy,
        elevation: 0,
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Android decides what Godfident may do. Each item below shows what is really switched on right now.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              for (final p in items)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.navySurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.granted ? AppTheme.emerald.withValues(alpha: 0.5) : AppTheme.navyOutline),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(p.granted ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: p.granted ? AppTheme.emerald : AppTheme.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${p.feature}${p.required ? '' : ' · optional'}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.goldDark)),
                        const SizedBox(height: 4),
                        Text(p.why, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ]),
                    ),
                    if (!p.granted)
                      TextButton(onPressed: () => _ask(p), child: const Text('Enable')),
                  ]),
                ),
            ]),
    );
  }
}
