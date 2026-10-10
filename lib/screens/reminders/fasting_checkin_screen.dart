import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/fasting_log.dart';
import '../../widgets/common/christian_art.dart';

/// Opened from the "Did you fast today?" notification.
class FastingCheckinScreen extends StatefulWidget {
  final int reminderId;
  final String title;
  const FastingCheckinScreen({super.key, required this.reminderId, this.title = 'Fasting'});
  @override
  State<FastingCheckinScreen> createState() => _FastingCheckinScreenState();
}

class _FastingCheckinScreenState extends State<FastingCheckinScreen> {
  bool? _answered;

  Future<void> _answer(bool fasted) async {
    await FastingLog.record(date: DateTime.now(), fasted: fasted, reminderId: widget.reminderId, title: widget.title);
    if (mounted) setState(() => _answered = fasted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      appBar: AppBar(title: const Text('Fasting'), leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.go('/reminders'))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const SizedBox(height: 170, child: ArtImage(fallbackScene: 'wheat', animate: true, radius: 20)),
        const SizedBox(height: 22),
        if (_answered == null) ...[
          const Text('Did you fast today?', style: TextStyle(fontFamily: 'Lora', fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(widget.title, style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _answer(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white, minimumSize: const Size(0, 54)),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Yes, I fasted', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _answer(false),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54)),
            icon: const Icon(Icons.highlight_off),
            label: const Text('Not this time', style: TextStyle(fontSize: 16)),
          ),
        ] else ...[
          Text(_answered! ? 'Well done.' : 'That is okay.',
              style: const TextStyle(fontFamily: 'Lora', fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            _answered!
                ? 'Your fast is recorded in this week’s activity. “Your Father, who sees what is done in secret, will reward you.” (Matthew 6:18)'
                : 'Start again at the next one. Godfident is here to help you begin, not to keep score against you.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.5, fontSize: 15),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: () => context.go('/reminders'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: AppTheme.inkNavy, minimumSize: const Size(0, 50)),
            child: const Text('Done'),
          ),
        ],
      ]),
    );
  }
}
