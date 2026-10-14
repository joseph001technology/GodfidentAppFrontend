import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/restriction_provider.dart';
import '../../services/focus_blocking_service.dart';
import '../../services/native_session.dart';

/// Daily time limits per app. Once an app has used its minutes for the day it
/// cannot be opened until midnight. A limit is locked for a week after it is
/// set (it cannot be raised or removed); reinstalling Godfident clears them.
class AppLimitsScreen extends ConsumerStatefulWidget {
  const AppLimitsScreen({super.key});
  @override
  ConsumerState<AppLimitsScreen> createState() => _AppLimitsScreenState();
}

class _AppLimitsScreenState extends ConsumerState<AppLimitsScreen> with WidgetsBindingObserver {
  final _svc = FocusBlockingService.instance;
  List<AppLimit>? _limits;
  bool _accessibility = true;
  bool _usage = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final l = await _svc.getLimits();
    final a = await _svc.isAccessibilityEnabled();
    final u = await _svc.hasUsageAccess();
    if (!mounted) return;
    setState(() {
      _limits = l..sort((x, y) => x.label.toLowerCase().compareTo(y.label.toLowerCase()));
      _accessibility = a;
      _usage = u;
    });
  }

  String _in(DateTime t) {
    final d = t.difference(DateTime.now());
    if (d.inHours >= 24) {
      final days = (d.inHours / 24).ceil();
      return '$days day${days == 1 ? '' : 's'}';
    }
    if (d.inHours >= 1) return '${d.inHours} hour${d.inHours == 1 ? '' : 's'}';
    return '${d.inMinutes.clamp(1, 59)} min';
  }

  String _fmtMin(int m) => m >= 60 ? '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60} min'}' : '$m min';

  Future<void> _snack(String m) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ── add / edit ─────────────────────────────────────────────────────
  Future<void> _add() async {
    final apps = await ref.read(installedAppsProvider.future);
    if (!mounted) return;
    final taken = (_limits ?? []).map((l) => l.packageName).toSet();
    final app = await showModalBottomSheet<InstalledApp>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.navySurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _AppPicker(apps: apps.where((a) => !taken.contains(a.packageName)).toList()),
    );
    if (app == null || !mounted) return;
    await _pickMinutes(app.packageName, app.label, null);
  }

  Future<void> _pickMinutes(String pkg, String label, AppLimit? existing) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppTheme.navySurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _MinutesSheet(label: label, initial: existing?.minutes ?? 30),
    );
    if (minutes == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Limit $label to ${_fmtMin(minutes)} a day?'),
        content: const Text(
          'Once the time is used up, this app cannot be opened until midnight.\n\n'
          'This limit is LOCKED for 7 days: you will not be able to raise, change or remove it before then. '
          'That is the point. Only reinstalling Godfident clears it earlier.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Set and lock')),
        ],
      ),
    );
    if (ok != true) return;
    final r = await _svc.setLimit(pkg, label, minutes);
    if (r == 'locked') await _snack('This limit is locked until its week is over.');
    if (r == 'protected') await _snack('Phone, Settings, keyboard and Godfident itself can never be limited.');
    if (r == 'invalid') await _snack('Could not save that limit.');
    await _load();
  }

  Future<void> _open(AppLimit l) async {
    if (l.locked) {
      await _snack('Locked for ${_in(l.lockedUntil)} more. It can be changed or removed after that.');
      return;
    }
    final act = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.navySurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Change the daily limit'),
            onTap: () => Navigator.pop(sheet, 'edit'),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: AppTheme.danger),
            title: Text('Remove the limit', style: TextStyle(color: AppTheme.danger)),
            onTap: () => Navigator.pop(sheet, 'remove'),
          ),
        ]),
      ),
    );
    if (act == 'edit') {
      await _pickMinutes(l.packageName, l.label, l);
    } else if (act == 'remove') {
      final r = await _svc.removeLimit(l.packageName);
      if (r == 'locked') await _snack('This limit is locked.');
      await _load();
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final limits = _limits;
    final icons = ref.watch(installedAppsProvider).valueOrNull ?? const <InstalledApp>[];
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: const Text('Daily app limits'),
        backgroundColor: AppTheme.navy,
        foregroundColor: AppTheme.ink,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.inkNavy,
        icon: const Icon(Icons.add),
        label: const Text('Add app'),
      ),
      body: limits == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
              Text(
                'Choose how long an app may be used each day. When the time is up, the app closes and stays closed until midnight. '
                'A limit is locked for 7 days once set, so a weak moment cannot undo it.',
                style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final ok = await NativeSession.openWellbeing();
                    if (!ok) await _snack('Could not find the phone\u2019s own app timers.');
                  },
                  icon: const Icon(Icons.timer_outlined, size: 18),
                  label: const Text('Also set the phone\u2019s own app timers'),
                ),
              ),
              const SizedBox(height: 6),
              if (!_accessibility)
                _warn('Turn on the Godfident Focus accessibility service so limits can close apps.', 'Turn on', _svc.openAccessibilitySettings),
              if (!_usage)
                _warn('Allow Usage access so Godfident can count the minutes each app is used.', 'Allow', _svc.requestUsageAccess),
              if (limits.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(children: [
                    Icon(Icons.hourglass_empty_rounded, size: 44, color: AppTheme.goldDark),
                    const SizedBox(height: 10),
                    const Text('No limits yet', style: TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Tap "Add app" to limit TikTok, Instagram, YouTube or any other app.',
                        textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
                  ]),
                ),
              for (final l in limits) _tile(l, icons.where((a) => a.packageName == l.packageName).firstOrNull?.icon),
            ]),
    );
  }

  Widget _warn(String text, String action, Future<void> Function() onTap) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, color: AppTheme.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
          TextButton(onPressed: onTap, child: Text(action)),
        ]),
      );

  Widget _tile(AppLimit l, dynamic icon) {
    final frac = l.usageKnown ? (l.usedMs / (l.minutes * 60000)).clamp(0.0, 1.0) : 0.0;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _open(l),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: l.reached ? AppTheme.danger.withValues(alpha: 0.5) : AppTheme.navyOutline),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            icon == null ? const Icon(Icons.android, size: 34) : Image.memory(icon, width: 34, height: 34, gaplessPlayback: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  l.usageKnown ? '${_fmtMin(l.usedMinutes)} used of ${_fmtMin(l.minutes)} today' : 'Limit ${_fmtMin(l.minutes)} a day',
                  style: TextStyle(fontSize: 12, color: l.reached ? AppTheme.danger : AppTheme.textSecondary),
                ),
              ]),
            ),
            Icon(l.locked ? Icons.lock_outline : Icons.lock_open_outlined, size: 20, color: l.locked ? AppTheme.goldDark : AppTheme.emerald),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 6,
              backgroundColor: AppTheme.navyVariant,
              color: l.reached ? AppTheme.danger : AppTheme.gold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.reached
                ? 'Time is up. Opens again tomorrow.'
                : l.locked
                    ? 'Locked for ${_in(l.lockedUntil)} more'
                    : 'Unlocked: tap to change or remove',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ]),
      ),
    );
  }
}

class _AppPicker extends StatefulWidget {
  final List<InstalledApp> apps;
  const _AppPicker({required this.apps});
  @override
  State<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<_AppPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final shown = widget.apps.where((a) => a.label.toLowerCase().contains(_q.toLowerCase())).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Which app?', style: TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search your apps'),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: shown.length,
                itemBuilder: (_, i) {
                  final a = shown[i];
                  return ListTile(
                    leading: a.icon == null ? const Icon(Icons.android) : Image.memory(a.icon!, width: 36, height: 36, gaplessPlayback: true),
                    title: Text(a.label),
                    onTap: () => Navigator.pop(context, a),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MinutesSheet extends StatefulWidget {
  final String label;
  final int initial;
  const _MinutesSheet({required this.label, required this.initial});
  @override
  State<_MinutesSheet> createState() => _MinutesSheetState();
}

class _MinutesSheetState extends State<_MinutesSheet> {
  late double _m = widget.initial.clamp(5, 240).toDouble();

  String _fmt(int m) => m >= 60 ? '${m ~/ 60} h${m % 60 == 0 ? '' : ' ${m % 60} min'}' : '$m min';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Daily limit for ${widget.label}', style: const TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Center(child: Text(_fmt(_m.round()), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppTheme.goldAccent))),
          Slider(
            value: _m,
            min: 5,
            max: 240,
            divisions: 47,
            activeColor: AppTheme.gold,
            onChanged: (v) => setState(() => _m = v),
          ),
          Wrap(spacing: 8, children: [
            for (final p in const [15, 30, 60, 90, 120])
              ChoiceChip(
                label: Text(_fmt(p)),
                selected: _m.round() == p,
                onSelected: (_) => setState(() => _m = p.toDouble()),
              ),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _m.round()),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold, foregroundColor: AppTheme.inkNavy, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Continue'),
            ),
          ),
        ]),
      ),
    );
  }
}
