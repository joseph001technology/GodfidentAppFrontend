import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/music_controller.dart';
import '../../services/session_ticker.dart';

/// Bottom navigation: Home, Bible, Focus, Reminders, Profile.
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
    if (location.startsWith('/settings')) return _tabs.length - 1;
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
          color: AppTheme.heroSurface,
          shape: Border(top: BorderSide(color: AppTheme.heroBorder)),
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
                    activeTrackColor: AppTheme.heroAccent,
                    inactiveTrackColor: AppTheme.heroTrack,
                    thumbColor: AppTheme.heroAccent,
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
                  Icon(Icons.music_note, color: AppTheme.heroAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.onHero, fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.onHeroMuted, fontSize: 11)),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Previous song',
                    icon: Icon(Icons.skip_previous, color: AppTheme.heroAccent),
                    onPressed: m.previous, // restarts the song first, then goes back
                  ),
                  StreamBuilder<PlayerState>(
                    stream: m.player.playerStateStream,
                    builder: (_, snap) {
                      final playing = snap.data?.playing ?? m.isPlaying;
                      return IconButton(
                        tooltip: playing ? 'Pause' : 'Play',
                        icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: AppTheme.heroAccent, size: 34),
                        onPressed: m.toggle,
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Next song',
                    icon: Icon(Icons.skip_next, color: AppTheme.heroAccent),
                    onPressed: m.hasNext ? m.next : null,
                  ),
                  IconButton(
                    tooltip: 'Close player',
                    icon: Icon(Icons.close, color: AppTheme.onHeroMuted, size: 20),
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
/// every screen except the Focus and Prayer pages (which show it themselves).
/// Tapping it returns to the session.
class _SessionBanner extends StatefulWidget {
  const _SessionBanner();
  @override
  State<_SessionBanner> createState() => _SessionBannerState();
}

class _SessionBannerState extends State<_SessionBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The same clock as the Prayer page and the Focus page (see SessionTicker),
    // so the three always show the same time. The ticker also finishes and records
    // a session whose time ran out while you were elsewhere.
    return ValueListenableBuilder<SessionSnapshot>(
      valueListenable: SessionTicker.instance,
      builder: (context, snap, _) {
        if (!snap.active) return const SizedBox.shrink();
        final info = snap.info;
        final prayer = info.purpose == 'prayer';
        final route = '/focus';
        final loc = GoRouterState.of(context).matchedLocation;
        // The Focus page and the Prayer page already show the big timer.
        if (loc == route || loc == '/prayer') return const SizedBox.shrink();
        final what = prayer ? 'Praying' : info.purpose == 'bible' ? 'Bible time' : info.purpose == 'both' ? 'Time with God' : 'Focus';
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
                    snap.frozen ? '$what · frozen. Tap to resume' : '$what · time left',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.inkNavy, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Text(
                  formatSessionLeft(snap.left),
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
      },
    );
  }
}
