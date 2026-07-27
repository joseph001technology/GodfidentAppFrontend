import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class ShellScaffold extends StatefulWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold> {
  int _locationToIndex(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/bible')) return 1;
    if (location.startsWith('/prayer')) return 2;
    if (location.startsWith('/notes')) return 3;
    if (location.startsWith('/analytics')) return 4;
    if (location.startsWith('/profile')) return 5;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/home'); break;
      case 1: context.go('/bible'); break;
      case 2: context.go('/prayer'); break;
      case 3: context.go('/notes'); break;
      case 4: context.go('/analytics'); break;
      case 5: context.go('/profile'); break;
    }
  }

  void _showFabMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navySurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FabMenu(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _locationToIndex(location);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppTheme.navy,
        selectedItemColor: AppTheme.emerald,
        unselectedItemColor: AppTheme.warmGray,
        currentIndex: index,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => _onTap(context, i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Bible',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.volunteer_activism_outlined),
            activeIcon: Icon(Icons.volunteer_activism),
            label: 'Prayer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_note_outlined),
            activeIcon: Icon(Icons.edit_note),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showFabMenu(context),
      backgroundColor: AppTheme.emerald,
      elevation: 8,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }
}

/// FAB Menu for quick actions
class _FabMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.warmGray.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // Quick action buttons
          _QuickActionButton(
            icon: Icons.volunteer_activism,
            label: 'Start Prayer',
            color: AppTheme.emerald,
            onTap: () {
              Navigator.pop(context);
              context.go('/prayer/new');
            },
          ),
          const SizedBox(height: 12),
          _QuickActionButton(
            icon: Icons.edit_note,
            label: 'Create Note',
            color: AppTheme.softBlue,
            onTap: () {
              Navigator.pop(context);
              context.go('/notes/new');
            },
          ),
          const SizedBox(height: 12),
          _QuickActionButton(
            icon: Icons.notifications,
            label: 'New Reminder',
            color: AppTheme.gold,
            onTap: () {
              Navigator.pop(context);
              context.go('/reminders/new');
            },
          ),
          const SizedBox(height: 12),
          _QuickActionButton(
            icon: Icons.rule,
            label: 'Create Rule',
            color: AppTheme.midnightPurple,
            onTap: () {
              Navigator.pop(context);
              context.go('/rules/new');
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}