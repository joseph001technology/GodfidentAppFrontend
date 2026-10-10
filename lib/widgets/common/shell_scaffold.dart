import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/music_controller.dart';
import '../../services/focus_session_manager.dart';

/// Bottom navigation, matching the prototype: Home, Bible, Focus, Reminders, Profile.
/// Prayer and Notes stay one tap away from Home.
class ShellScaffold extends StatelessWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  static const _tabs = <_Tab>[
    _Tab('/home', 'Home', Icons.home_outlined, Icons.home),
    _Tab('/bible', 'Bible', Icons.menu_book_outlined, Icons.menu_book),
    _Tab('/focus', 'Focus', Icons.shield_outlined, Icons.shield),
    _Tab('/reminders', 'Reminders', Icons.notifications_none, Icons.notifications),
    _Tab('/profile', 'Profile', Icons.person_outline, Icons.person),
  ];

  int _indexFor(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexFor(location);
    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: Column(children: [
        Expanded(child: child),
        // A running Focus / Prayer session is visible on EVERY screen.
        const _SessionBanner(),
        // The one player of the app: shows on every tab, including Music.
        const _MiniPlayer(),
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.navySurface,
          border: Border(top: BorderSide(color: AppTheme.navyOutline)),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            currentIndex: index,
            selectedItemColor: AppTheme.goldDark,
            unselectedItemColor: AppTheme.textMuted,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            onTap: (i) => context.go(_tabs[i].path),
            items: [
              for (final t in _tabs)
                BottomNavigationBarItem(icon: Icon(t.icon), activeIcon: Icon(t.activeIcon), label: t.label),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab {
  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _Tab(this.path, this.label, this.icon, this.activeIcon);
}


class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context) {
    final m = MusicController.instance;
    return ListenableBuilder(
      listenable: m,
      builder: (context, _) {
        final song = m.current;
        if (song == null) return const SizedBox.shrink();
        return Material(
          color: AppTheme.inkNavy,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Thin progress line; drag it to seek.
            StreamBuilder<Duration>(
              stream: m.player.positionStream,
              builder: (_, snap) {
                final pos = snap.data ?? Duration.zero;
                final dur = m.player.duration ?? song.duration;
                final total = dur.inMilliseconds <= 0 ? 1.0 : dur.inMilliseconds.toDouble();
                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: AppTheme.goldLight,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppTheme.goldLight,
                  ),
                  child: SizedBox(
                    height: 16,
                    child: Slider(
                      value: pos.inMilliseconds.toDouble().clamp(0, total),
                      max: total,
                      onChanged: (v) => m.seek(Duration(milliseconds: v.toInt())),
                    ),
                  ),
                );
              },
            ),
            InkWell(
              onTap: () {
                if (!GoRouterState.of(context).matchedLocation.startsWith('/music')) context.push('/music');
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
                child: Row(children: [
                  const Icon(Icons.music_note, color: AppTheme.goldLight, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textOnDark, fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textOnDarkMuted, fontSize: 11)),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Previous song',
                    icon: const Icon(Icons.skip_previous, color: AppTheme.goldLight),
                    onPressed: m.previous, // restarts the song first, then goes back
                  ),
                  StreamBuilder<PlayerState>(
                    stream: m.player.playerStateStream,
                    builder: (_, snap) {
                      final playing = snap.data?.playing ?? m.isPlaying;
                      return IconButton(
                        tooltip: playing ? 'Pause' : 'Play',
                        icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: AppTheme.goldLight, size: 34),
                        onPressed: m.toggle,
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Next song',
                    icon: const Icon(Icons.skip_next, color: AppTheme.goldLight),
                    onPressed: m.hasNext ? m.next : null,
                  ),
                  IconButton(
                    tooltip: 'Close player',
                    icon: const Icon(Icons.close, color: AppTheme.textOnDarkMuted, size: 20),
                    onPressed: m.stop,
                  ),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}


/// Strip above the bottom bar that shows the running session's countdown on
/// every screen. Tapping it returns to the session. It also finishes (and
/// records) a session whose time ran out while you were elsewhere.
class _SessionBanner extends StatefulWidget {
  const _SessionBanner();
  @override
  State<_SessionBanner> createState() => _SessionBannerState();
}

class _SessionBannerState extends State<_SessionBanner> with SingleTickerProviderStateMixin {
  final _sm = SessionManager.instance;
  SessionInfo _info = const SessionInfo();
  Timer? _tick;
  int _n = 0;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _sm.changes.addListener(_refresh);
    _refresh();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pulse.dispose();
    _sm.changes.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final i = await _sm.info();
    if (mounted) setState(() => _info = i);
  }

  Future<void> _onTick() async {
    if (!mounted) return;
    _n++;
    if (_info.active && !_info.frozen && _info.endAt != null && !_info.endAt!.isAfter(DateTime.now())) {
      await _sm.reconcile(); // time is up: record it and clear the banner
      await _refresh();
      return;
    }
    if (_n % 5 == 0) {
      await _refresh(); // catches sessions started or ended from elsewhere
    } else if (_info.active) {
      setState(() {});
    }
  }

  String _fmt(Duration d) {
    final s = d.inSeconds.clamp(0, 1 << 30);
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    final mm = m.toString().padLeft(2, '0'), ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    if (!_info.active) return const SizedBox.shrink();
    final prayer = _info.purpose == 'prayer';
    final route = prayer ? '/prayer/focus' : '/focus';
    final loc = GoRouterState.of(context).matchedLocation;
    // The session screen already shows the big timer.
    if (loc == route) return const SizedBox.shrink();
    final what = prayer ? 'Praying' : _info.purpose == 'bible' ? 'Bible time' : _info.purpose == 'both' ? 'Time with God' : 'Focus';
    final left = _info.left.isNegative ? Duration.zero : _info.left;
    return Material(
      color: AppTheme.gold,
      child: InkWell(
        onTap: () => context.go(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(children: [
            FadeTransition(
              opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
              child: Icon(prayer ? Icons.volunteer_activism : Icons.shield, color: AppTheme.inkNavy, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _info.frozen ? '$what \u00b7 frozen. Tap to resume' : '$what \u00b7 time left',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.inkNavy, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            Text(
              _fmt(left),
              style: TextStyle(
                color: AppTheme.inkNavy,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: AppTheme.inkNavy),
          ]),
        ),
      ),
    );
  }
}
