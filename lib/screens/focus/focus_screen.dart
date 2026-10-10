import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/scheduled_focus.dart';
import '../../providers/restriction_provider.dart';
import '../../providers/scheduled_focus_provider.dart';
import '../../services/focus_blocking_service.dart';
import '../../services/focus_session_manager.dart';
import '../../services/restriction_store.dart';
import '../../services/permissions_service.dart';
import '../../services/website_protection_service.dart';
import '../../widgets/common/session_extras.dart';
import '../../widgets/common/session_music_card.dart';

/// Focus Mode: pick a duration, then start a REAL Android restriction session.
/// The screen only shows "active" after the native service confirms it.
class FocusScreen extends ConsumerStatefulWidget {
  /// Set when opened from a ringing scheduled-session notification.
  final int? startScheduleId;
  const FocusScreen({super.key, this.startScheduleId});
  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> with WidgetsBindingObserver {
  int _minutes = 30;
  bool _allowOnly = false;
  bool _busy = false;
  String? _message;
  Map<String, dynamic> _session = const {'active': false};
  bool _frozen = false;
  Duration _frozenLeft = Duration.zero;
  List<PermissionItem> _perms = const [];
  Timer? _tick;
  ScheduledFocus? _due; // the scheduled session whose alarm brought us here
  String? _purpose; // bible | prayer | both, of the running session

  final _focus = FocusBlockingService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RestrictionStore.instance.getAllowOnly().then((v) {
      if (mounted) setState(() => _allowOnly = v);
    });
    _refresh();
    final sid = widget.startScheduleId;
    if (sid != null) {
      ref.read(scheduledFocusProvider.notifier).byId(sid).then((f) {
        if (mounted && f != null) setState(() => _due = f);
      });
    }
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final endAt = (_session['endAtMs'] as num?)?.toInt() ?? 0;
      if (_frozen) return;
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

  final _sessions = SessionManager.instance;

  Future<void> _refresh() async {
    // A session that ran out while the app was closed is recorded here.
    await _sessions.reconcile();
    final info = await _focus.getSessionInfo();
    final live = await _sessions.info();
    final perms = await PermissionsService.instance.snapshot();
    if (mounted) {
      setState(() {
        _session = {
          ...info,
          'active': live.active,
          'endAtMs': live.endAt?.millisecondsSinceEpoch ?? 0,
        };
        _frozen = live.frozen;
        _frozenLeft = live.frozenLeft;
        if (live.active) _purpose = live.purpose.isEmpty ? null : live.purpose;
        _perms = perms;
      });
    }
  }

  Future<void> _start({ScheduledFocus? from}) async {
    final minutes = from?.durationMinutes ?? _minutes;
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
    final r = await _sessions.start(
      minutes: minutes,
      purpose: from?.purpose ?? '',
      requireBlocking: true,
      title: from?.displayTitle ?? '',
    );
    if (r.ok && from != null) {
      await ref.read(scheduledFocusProvider.notifier).started(from); // stops the ringing
      _due = null;
    }
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = r.ok ? null : r.message;
    });
  }

  Future<void> _freeze() async {
    setState(() => _busy = true);
    await _sessions.freeze();
    await _refresh();
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Session frozen. You haven't finished \u2014 we'll remind you every 10 minutes."),
      ));
    }
  }

  Future<void> _extend(int minutes) async {
    setState(() => _busy = true);
    await _sessions.extend(minutes);
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $minutes minutes to your session.')));
  }

  Future<void> _resume() async {
    setState(() => _busy = true);
    await _sessions.resume();
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  /// Ending early is deliberately hard: it needs a typed word, it is only
  /// offered while the session is frozen, and an unfinished session is not recorded.
  Future<void> _giveUp() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          backgroundColor: AppTheme.navySurface,
          title: const Text('Give up this session?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('It will NOT be counted in your activity. Your time with God is worth finishing.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setD(() {}),
              decoration: const InputDecoration(hintText: 'Type END to confirm'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep going')),
            TextButton(
              onPressed: ctrl.text.trim().toUpperCase() == 'END' ? () => Navigator.pop(d, true) : null,
              child: const Text('End session', style: TextStyle(color: AppTheme.danger)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    await _sessions.end(early: true);
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
            Text('Focus Mode',
                style: TextStyle(fontFamily: 'Lora', fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.ink)),
            const SizedBox(height: 4),
            Text('Protect your time with God.', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            if (_due != null) ...[_dueCard(_due!, active), const SizedBox(height: 14)],
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
            _scheduledSection(),
            const SizedBox(height: 22),
            Text('PROTECTION',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppTheme.textMuted)),
            const SizedBox(height: 10),
            _row(
              icon: Icons.apps_rounded,
              title: 'App Restrictions',
              sub: apps.isEmpty
                  ? 'No apps selected'
                  : '${apps.length} app${apps.length == 1 ? '' : 's'} \u00b7 blocked during Focus sessions',
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
    final state = (web?.running ?? false) ? 'Always on' : (count == 0 ? 'Not set up' : 'Off');
    return '$state \u00b7 $count site${count == 1 ? '' : 's'} protected';
  }

  Widget _setupCard(List<RestrictedApp> apps) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Duration', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
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
    final left = _frozen
        ? _frozenLeft
        : (endAt == 0 ? null : Duration(milliseconds: (endAt - DateTime.now().millisecondsSinceEpoch).clamp(0, 1 << 40)));
    String fmt(Duration d) {
      final m = d.inMinutes, s = d.inSeconds % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(border: _frozen ? AppTheme.accentTeal : AppTheme.gold),
      child: Column(children: [
        // A quiet animation (no sound) while you spend this time with God.
        SessionScene(purpose: _purpose ?? '', height: 150),
        const SizedBox(height: 12),
        Icon(_frozen ? Icons.ac_unit_rounded : Icons.shield_rounded, color: _frozen ? AppTheme.accentTeal : AppTheme.gold, size: 36),
        const SizedBox(height: 8),
        Text(_frozen ? 'Session frozen' : 'Focus session active',
            style: const TextStyle(fontFamily: 'Lora', fontSize: 20, fontWeight: FontWeight.bold)),
        if (_purpose != null && ScheduledFocus.purposes[_purpose] != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(ScheduledFocus.purposes[_purpose]!, style: const TextStyle(color: AppTheme.goldDark, fontWeight: FontWeight.w600)),
          ),
        if (left != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(fmt(left),
                style: TextStyle(
                    fontSize: 40, fontWeight: FontWeight.w700, color: _frozen ? AppTheme.textMuted : AppTheme.ink)),
          ),
        if (_frozen)
          Text(
            "You haven't finished yet. Nothing is blocked while frozen, and we'll remind you every 10 minutes.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          )
        else ...[
          Text(
            _session['allowOnly'] == true ? 'Only Godfident is allowed.' : 'Blocked apps are being sent back here.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          Text('${_session['attempts'] ?? 0} blocked attempt(s)',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        ],
        const SizedBox(height: 14),
        const SessionMusicCard(),
        const SizedBox(height: 14),
        ExtendSessionRow(busy: _busy, onExtend: _extend),
        const SizedBox(height: 14),
        if (_frozen) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _resume,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Resume session'),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _giveUp,
            child: Text('Give up this session', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ),
        ] else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _freeze,
              icon: const Icon(Icons.ac_unit_rounded),
              label: const Text('Freeze'),
            ),
          ),
      ]),
    );
  }

  Widget _dueCard(ScheduledFocus f, bool active) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(border: AppTheme.gold),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Your time with God is starting',
            style: TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${f.displayTitle} \u00b7 ${f.purposeLabel} \u00b7 ${f.durationLabel}',
            style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy
                ? null
                : () async {
                    if (active) {
                      // Already in a session: just stop the ringing.
                      await ref.read(scheduledFocusProvider.notifier).started(f);
                      if (mounted) setState(() => _due = null);
                    } else {
                      await _start(from: f);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.inkNavy,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(active ? 'Silence alarm' : 'Start'),
          ),
        ),
      ]),
    );
  }

  Widget _scheduledSection() {
    final list = ref.watch(scheduledFocusProvider).valueOrNull ?? const <ScheduledFocus>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text('SCHEDULED SESSIONS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppTheme.textMuted)),
        ),
        TextButton.icon(
          onPressed: () => context.push('/focus/schedule/new'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add'),
        ),
      ]),
      if (list.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: _cardDeco(),
          child: Text(
            'Pre-set a time with God, e.g. 6:00 AM every day. Your phone will ring at that time and the session starts when you press Start.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ),
      for (final f in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/focus/schedule/${f.id}'),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: _cardDeco(),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${f.timeLabel}  \u00b7  ${f.displayTitle}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: f.enabled ? AppTheme.textPrimary : AppTheme.textMuted)),
                    const SizedBox(height: 2),
                    Text('${f.durationLabel} \u00b7 ${f.purposeLabel} \u00b7 ${f.repeatLabel}',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ]),
                ),
                Switch(
                  value: f.enabled,
                  activeThumbColor: AppTheme.gold,
                  onChanged: (v) => ref.read(scheduledFocusProvider.notifier).toggle(f, v),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: AppTheme.textMuted),
                  tooltip: 'Delete',
                  onPressed: () => ref.read(scheduledFocusProvider.notifier).delete(f.id),
                ),
              ]),
            ),
          ),
        ),
    ]);
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
            Text(body, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
        child: Text(text, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
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
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textMuted),
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
