import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../providers/restriction_provider.dart';
import '../../repositories/prayer_repository.dart';
import '../../services/focus_session_manager.dart';
import '../../widgets/common/session_extras.dart';
import '../../widgets/common/session_music_card.dart';

/// Prayer Focus: works like Focus Mode, for prayer. Choose how long you want
/// to pray, your chosen apps are blocked, a notification tells you when the
/// time is up, and the day is recorded as a day you prayed.
class PrayerFocusScreen extends ConsumerStatefulWidget {
  /// Opened from a prayer reminder: start at once with the last chosen time.
  final bool autoStart;
  const PrayerFocusScreen({super.key, this.autoStart = false});

  @override
  ConsumerState<PrayerFocusScreen> createState() => _PrayerFocusScreenState();
}

class _PrayerFocusScreenState extends ConsumerState<PrayerFocusScreen> with WidgetsBindingObserver {
  static const _kMinutes = 'prayer_focus_minutes';
  static const _kBlock = 'prayer_focus_block';

  final _sessions = SessionManager.instance;
  final _title = TextEditingController();
  int _minutes = 15;
  bool _block = true;
  bool _busy = false;
  String? _message;
  SessionInfo _info = const SessionInfo();
  bool _done = false;
  int _doneMinutes = 0;
  Map<String, dynamic> _streak = const {};
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    _minutes = p.getInt(_kMinutes) ?? 15;
    _block = p.getBool(_kBlock) ?? true;
    await _refresh();
    _loadStreak();
    if (widget.autoStart && !_info.active && mounted) await _start();
  }

  Future<void> _loadStreak() async {
    try {
      final s = await PrayerRepository().getStreak();
      if (mounted) setState(() => _streak = s);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _title.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final was = _info.active;
    final planned = _info.plannedMinutes;
    await _sessions.reconcile();
    final now = await _sessions.info();
    if (!mounted) return;
    setState(() {
      _info = now;
      if (was && !now.active) {
        _done = true; // the time ran out
        _doneMinutes = planned;
        _loadStreak();
      }
    });
  }

  void _onTick() {
    if (!mounted || !_info.active || _info.frozen) return;
    if (_info.endAt != null && !_info.endAt!.isAfter(DateTime.now())) {
      _refresh();
    } else {
      setState(() {});
    }
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _message = null;
      _done = false;
    });
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kMinutes, _minutes);
    await p.setBool(_kBlock, _block);
    final r = await _sessions.start(
      minutes: _minutes,
      purpose: 'prayer',
      block: _block,
      title: _title.text.trim(),
    );
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = r.ok
          ? (_block && !r.blocking
              ? 'Praying without app blocking: choose apps in Focus > App Restrictions and allow the Focus accessibility service to block them too.'
              : null)
          : r.message;
    });
  }

  Future<void> _freeze() async {
    setState(() => _busy = true);
    await _sessions.freeze();
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Prayer frozen. You haven't finished \u2014 we'll remind you every 10 minutes."),
    ));
  }

  Future<void> _extend(int minutes) async {
    setState(() => _busy = true);
    await _sessions.extend(minutes);
    await _refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $minutes minutes to your prayer time.')));
  }

  Future<void> _resume() async {
    setState(() => _busy = true);
    await _sessions.resume();
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  /// Only offered while frozen, needs a typed word, and an unfinished prayer is not recorded.
  Future<void> _giveUp() async {
    final ctrl = TextEditingController();
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: const Text('Give up this prayer time?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('An unfinished prayer session is not recorded in your activity.'),
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
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep praying')),
            TextButton(
              onPressed: ctrl.text.trim().toUpperCase() == 'END' ? () => Navigator.pop(d, true) : null,
              child: const Text('End'),
            ),
          ],
        ),
      ),
    );
    if (yes != true) return;
    setState(() => _busy = true);
    await _sessions.end(early: true);
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = false;
    });
  }

  String _fmt(Duration d) {
    final s = d.inSeconds.clamp(0, 1 << 30);
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final running = _info.active && _info.purpose == 'prayer';
    final otherRunning = _info.active && _info.purpose != 'prayer';
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(
        title: const Text('Prayer Focus', style: TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/prayer')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          if (running)
            _runningCard()
          else if (_done)
            _doneCard()
          else if (otherRunning)
            _card(const Text('A Focus session is already running. End it first to start a prayer session.'))
          else
            _setupCard(),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.gold.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: Text(_message!, style: const TextStyle(fontSize: 13)),
            ),
          ],
          const SizedBox(height: 18),
          _streakRow(),
        ],
      ),
    );
  }

  Widget _card(Widget child, {Color? border}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border ?? AppTheme.navyOutline),
        ),
        child: child,
      );

  Widget _setupCard() {
    final apps = ref.watch(restrictedAppsProvider).valueOrNull ?? [];
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('How long do you want to pray?', style: TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton.filledTonal(
          onPressed: _minutes > 1 ? () => setState(() => _minutes = _minutes <= 5 ? _minutes - 1 : _minutes - 5) : null,
          icon: const Icon(Icons.remove),
        ),
        const SizedBox(width: 18),
        Column(children: [
          Text('$_minutes', style: TextStyle(fontSize: 54, fontWeight: FontWeight.w700, color: AppTheme.ink, height: 1)),
          Text('minutes', style: TextStyle(color: AppTheme.textSecondary)),
        ]),
        const SizedBox(width: 18),
        IconButton.filledTonal(
          onPressed: _minutes < 180 ? () => setState(() => _minutes = _minutes < 5 ? 5 : _minutes + 5) : null,
          icon: const Icon(Icons.add),
        ),
      ]),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final m in const [5, 10, 15, 20, 30, 45, 60])
          ChoiceChip(
            label: Text(m < 60 ? '$m min' : '1 hr'),
            selected: _minutes == m,
            selectedColor: AppTheme.gold,
            labelStyle: TextStyle(color: _minutes == m ? AppTheme.inkNavy : AppTheme.textPrimary, fontWeight: FontWeight.w600),
            onSelected: (_) => setState(() => _minutes = m),
          ),
      ]),
      const SizedBox(height: 16),
      TextField(
        controller: _title,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'What are you praying about? (optional)'),
      ),
      const SizedBox(height: 6),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: AppTheme.gold,
        title: const Text('Block distracting apps', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          apps.isEmpty ? 'No apps chosen yet. Choose them in Focus > App Restrictions.' : '${apps.length} app${apps.length == 1 ? '' : 's'} will be blocked while you pray.',
          style: const TextStyle(fontSize: 12),
        ),
        value: _block,
        onChanged: (v) => setState(() => _block = v),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _busy ? null : _start,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            foregroundColor: AppTheme.inkNavy,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.volunteer_activism),
          label: Text('Start $_minutes minute prayer'),
        ),
      ),
    ]));
  }

  Widget _runningCard() {
    final left = _info.left;
    final total = _info.plannedMinutes * 60;
    final progress = total == 0 ? 0.0 : (1 - left.inSeconds / total).clamp(0.0, 1.0);
    return _card(
      Column(children: [
        // A quiet animation (no sound) while you pray.
        const SessionScene(purpose: 'prayer', height: 150),
        const SizedBox(height: 14),
        const Text('Be still. God is listening.', style: TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 18),
        SizedBox(
          width: 190,
          height: 190,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 190,
              height: 190,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 10,
                color: AppTheme.gold,
                backgroundColor: AppTheme.navyVariant,
              ),
            ),
            Text(_fmt(left), style: TextStyle(fontSize: 42, fontWeight: FontWeight.w700, color: AppTheme.ink)),
          ]),
        ),
        const SizedBox(height: 14),
        Text(
            _info.frozen
                ? "Frozen \u2014 you haven't finished. We'll remind you every 10 minutes."
                : (_info.blocking ? 'Your chosen apps are blocked.' : 'Timer only. No apps are being blocked.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 14),
        const SessionMusicCard(),
        const SizedBox(height: 14),
        ExtendSessionRow(busy: _busy, onExtend: _extend),
        const SizedBox(height: 14),
        if (_info.frozen) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _resume,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Resume prayer'),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _giveUp,
            child: Text('Give up this prayer time', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ),
        ] else
          OutlinedButton.icon(
            onPressed: _busy ? null : _freeze,
            icon: const Icon(Icons.ac_unit_rounded),
            label: const Text('Freeze'),
          ),
      ]),
      border: AppTheme.gold,
    );
  }

  Widget _doneCard() => _card(
        Column(children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 52),
          const SizedBox(height: 8),
          const Text('Amen', style: TextStyle(fontFamily: 'Lora', fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('You prayed for $_doneMinutes minute${_doneMinutes == 1 ? '' : 's'}. Today is recorded as a day you prayed.',
              textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _done = false),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: AppTheme.inkNavy),
              child: const Text('Pray again'),
            ),
          ),
        ]),
        border: AppTheme.emerald,
      );

  Widget _streakRow() {
    final cur = (_streak['current_streak'] as num?)?.toInt() ?? 0;
    final best = (_streak['longest_streak'] as num?)?.toInt() ?? 0;
    final days = (_streak['total_days_prayed'] as num?)?.toInt() ?? 0;
    Widget cell(String v, String l) => Expanded(
          child: Column(children: [
            Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.ink)),
            Text(l, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ]),
        );
    return _card(Row(children: [cell('$cur', 'day streak'), cell('$best', 'best streak'), cell('$days', 'days prayed')]));
  }
}
