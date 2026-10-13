import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'christian_art.dart';

/// "Need more time?" chips: +5, +10, +15, +30 minutes on the running session.
class ExtendSessionRow extends StatelessWidget {
  final bool busy;
  final Future<void> Function(int minutes) onExtend;
  const ExtendSessionRow({super.key, required this.busy, required this.onExtend});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text('Need more time with God?', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
        for (final m in const [5, 10, 15, 30])
          ActionChip(
            label: Text('+$m min', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.inkNavy)),
            backgroundColor: AppTheme.gold.withValues(alpha: 0.85),
            side: BorderSide.none,
            onPressed: busy ? null : () => onExtend(m),
          ),
      ]),
    ]);
  }
}

/// A quiet, silent animation shown at the top of a running session.
class SessionScene extends StatelessWidget {
  /// 'prayer' | 'bible' | 'both' | ''
  final String purpose;
  final double height;
  const SessionScene({super.key, required this.purpose, this.height = 150});

  /// The built-in scene for a purpose (also used for the notification picture).
  static String sceneFor(String purpose) {
    switch (purpose) {
      case 'prayer':
        return 'dove';
      case 'bible':
        return 'scroll';
      case 'both':
        return 'sunrise';
      default:
        return 'cross';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: KeyedArt(artKey: 'session_$purpose', fallbackScene: sceneFor(purpose), height: height, radius: 16),
    );
  }
}
