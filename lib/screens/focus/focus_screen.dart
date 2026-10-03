import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/restriction_provider.dart';
import '../../repositories/focus_repository.dart';
import '../../services/focus_blocking_service.dart';
import '../../services/restriction_store.dart';
import '../../services/permissions_service.dart';
import '../../services/website_protection_service.dart';

/// Focus Mode: pick a duration, then start a REAL Android restriction session.
/// The screen only shows "active" after the native service confirms it.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});
  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> with WidgetsBindingObserver {
  int _minutes = 30;
  bool _allowOnly = false;
  bool _busy = false;
  String? _message;
  Map<String, dynamic> _session = const {'active': false};
  List<PermissionItem> _perms = const [];
  Timer? _tick;

  final _focus = FocusBlockingService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RestrictionStore.instance.getAllowOnly().then((v) {
      if (mounted) setState(() => _allowOnly = v);
    });
    _refresh();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final endAt = (_session['endAtMs'] as num?)?.toInt() ?? 0;
      if (_session['active'] == true && endAt != 0 && endAt <= DateTime.now().millisecondsSinceEpoch) {
        _refresh();
      } else if (_session['active'] == true) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      ref.invalidate(usageAccessProvider);
      ref.invalidate(websiteStatusProvider);
      _showBlockedAttempt();
    }
  }

  Future<void> _showBlockedAttempt() async {
    final label = await _focus.getLastBlockedApp();
    if (label != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label is blocked during your focus session.')),
      );
    }
  }

  static const _kSessionId = 'focus_backend_session_id';

  Future<void> _refresh() async {
    final info = await _focus.getSessionInfo();
    final perms = await PermissionsService.instance.snapshot();
    if (mounted) {
      setState(() {
        _session = info;
        _perms = perms;
      });
    }
    if (info['active'] != true) _closeBackendSession();
  }

  /// Best-effort online record of the session. Enforcement never depends on this.
  Future<void> _openBackendSession() async {
    try {
      final s = await FocusRepository().startSession();
      (await SharedPreferences.getInstance()).setInt(_kSessionId, s.id);
    } catch (_) {/* offline: the session still runs on the device */}
  }

  Future<void> _closeBackendSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_kSessionId);
    if (id == null) return;
    try {
      await FocusRepository().endSession(id, durationMinutes: _minutes);
      await prefs.remove(_kSessionId);
    } catch (_) {/* try again next time the screen opens */}
  }

  Future<void> _start() async {
    final apps = ref.read(restrictedAppsProvider).valueOrNull ?? [];
    if (apps.isEmpty && !_allowOnly) {
      setState(() => _message = 'Choose at least one app to restrict first, or turn on "Only Godfident".');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    // Instant blocking needs the Accessibility service. Without it Android
    // does not let Godfident stop an app from opening, so we refuse to start
    // rather than show a session that is not actually protecting anything.
    final accessibility = await _focus.isAccessibilityEnabled();
    if (!accessibility) {
      setState(() {
        _busy = false;
        _message = 'Focus can\u2019t block apps yet: the Godfident Focus accessibility service is switched off. Open Permissions and enable it.';
      });
      if (mounted) context.push('/focus/permissions');
      return;
    }
    final ok = await _focus.startFocusSession(
      apps.map((a) => a.packageName).toList(),
      endAt: DateTime.now().add(Duration(minutes: _minutes)),
      allowOnly: _allowOnly,
    );
    if (ok) _openBackendSession();
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok ? null : 'Android did not start the restriction service, so no apps are being blocked.';
    });
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    await _focus.stopFocusSession();
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(restrictedAppsProvider).valueOrNull ?? [];
    final sites = ref.watch(restrictedSitesProvider).valueOrNull ?? [];
    final web = ref.watch(websiteStatusProvider).valueOrNull;
    final active = _session['active'] == true;

    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            const Text('Focus Mode',
                style: TextStyle(fontFamily: 'Lora', fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.inkNavy)),
            const SizedBox(height: 4),
            const Text('Protect your time with God.', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            if (active) _activeCard() else _setupCard(apps),
            if (_message != null) ...[
              const SizedBox(height: 12),
              _notice(_message!, error: true),
            ],
            if (_perms.any((p) => p.required && !p.granted)) ...[
              const SizedBox(height: 12),
              _permissionCard(
                'Permissions needed',
                '${_perms.where((p) => p.required && !p.granted).map((p) => p.title).join(', ')} ${_perms.where((p) => p.required && !p.granted).length == 1 ? 'is' : 'are'} not enabled yet, so some protection will not work.',
                'Review',
                () => context.push('/focus/permissions'),
              ),
            ],
            const SizedBox(height: 22),
            const Text('PROTECTION',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppTheme.textMuted)),
            const SizedBox(height: 10),
            _row(
              icon: Icons.apps_rounded,
              title: 'App Restrictions',
              sub: apps.isEmpty ? 'No apps selected' : '${apps.length} app${apps.length == 1 ? '' : 's'} selected',
              onTap: () => context.push('/focus/apps'),
            ),
            _row(
              icon: Icons.language_rounded,
              title: 'Website Protection',
              // Domains are deliberately NOT shown here - only a count, so the
              // list stays hidden until the Protection Key is entered.
              sub: _webSummary(sites.length, web),
              onTap: () => context.push('/focus/websites'),
            ),
          ],
        ),
      ),
    );
  }

  String _webSummary(int count, WebsiteProtectionStatus? web) {
    final state = (web?.running ?? false) ? 'Active' : 'Off';
    return '$state · $count site${count == 1 ? '' : 's'} protected';
  }

  Widget _setupCard(List<RestrictedApp> apps) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Duration', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 10),
        Wrap(spacing: 10, children: [
          for (final m in const [15, 30, 60, 120])
            ChoiceChip(
              label: Text(m < 60 ? '$m min' : '${m ~/ 60} hr'),
              selected: _minutes == m,
              selectedColor: AppTheme.gold,
              labelStyle: TextStyle(
                  color: _minutes == m ? AppTheme.inkNavy : AppTheme.textPrimary, fontWeight: FontWeight.w600),
              onSelected: (_) => setState(() => _minutes = m),
            ),
        ]),
        const SizedBox(height: 14),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppTheme.gold,
          title: const Text('Only Godfident', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text(
            'Every other app is sent back here (phone, keyboard and Settings stay usable).',
            style: TextStyle(fontSize: 12),
          ),
          value: _allowOnly,
          onChanged: (v) {
            setState(() => _allowOnly = v);
            RestrictionStore.instance.setAllowOnly(v);
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : _start,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.inkNavy,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Start $_minutes minute session'),
          ),
        ),
      ]),
    );
  }

  Widget _activeCard() {
    final endAt = (_session['endAtMs'] as num?)?.toInt() ?? 0;
    final left = endAt == 0 ? null : Duration(milliseconds: (endAt - DateTime.now().millisecondsSinceEpoch).clamp(0, 1 << 40));
    String fmt(Duration d) {
      final m = d.inMinutes, s = d.inSeconds % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(border: AppTheme.gold),
      child: Column(children: [
        const Icon(Icons.shield_rounded, color: AppTheme.gold, size: 36),
        const SizedBox(height: 8),
        const Text('Focus session active',
            style: TextStyle(fontFamily: 'Lora', fontSize: 20, fontWeight: FontWeight.bold)),
        if (left != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(fmt(left),
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: AppTheme.inkNavy)),
          ),
        Text(
          _session['allowOnly'] == true
              ? 'Only Godfident is allowed.'
              : 'Blocked apps are being sent back here.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 6),
        Text('${_session['attempts'] ?? 0} blocked attempt(s)',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: _busy ? null : _stop, child: const Text('End session')),
      ]),
    );
  }

  Widget _permissionCard(String title, String body, String action, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(border: AppTheme.danger.withValues(alpha: 0.5)),
      child: Row(children: [
        const Icon(Icons.info_outline, color: AppTheme.danger),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(body, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ]),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ]),
    );
  }

  Widget _notice(String text, {bool error = false}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (error ? AppTheme.danger : AppTheme.gold).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
      );

  Widget _row({required IconData icon, required String title, required String sub, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDeco(),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: AppTheme.navyVariant, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppTheme.goldDark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ]),
        ),
      ),
    );
  }

  BoxDecoration _cardDeco({Color? border}) => BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border ?? AppTheme.navyOutline),
      );
}
