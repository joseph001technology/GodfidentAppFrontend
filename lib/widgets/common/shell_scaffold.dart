import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/music_controller.dart';

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
        // Keeps showing (and playing) on every tab. The Music screen has its
        // own bigger player, so it is hidden there.
        if (!location.startsWith('/music')) const _MiniPlayer(),
      ]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
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
          child: InkWell(
            onTap: () => context.push('/music'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
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
                  icon: Icon(m.isPlaying ? Icons.pause : Icons.play_arrow, color: AppTheme.goldLight),
                  onPressed: m.toggle,
                ),
                IconButton(icon: const Icon(Icons.skip_next, color: AppTheme.goldLight), onPressed: m.hasNext ? m.next : null),
                IconButton(icon: const Icon(Icons.close, color: AppTheme.textOnDarkMuted, size: 20), onPressed: m.stop),
              ]),
            ),
          ),
        );
      },
    );
  }
}
