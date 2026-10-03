import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

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
      body: child,
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
