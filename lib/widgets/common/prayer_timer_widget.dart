import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class PrayerTimerWidget extends StatefulWidget {
  final int initialSeconds;
  final bool showCompact;
  final VoidCallback? onCompleted;

  const PrayerTimerWidget({
    super.key,
    this.initialSeconds = 300,
    this.showCompact = false,
    this.onCompleted,
  });

  @override
  State<PrayerTimerWidget> createState() => _PrayerTimerWidgetState();
}

class _PrayerTimerWidgetState extends State<PrayerTimerWidget>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  int _totalSeconds = 0;
  bool _isRunning = false;
  Timer? _timer;
  bool _isCompleted = false;
  late AnimationController _pulseController;

  static const _verses = [
    '"Be still, and know that I am God." — Psalm 46:10',
    '"Do not be anxious about anything, but in every situation, by prayer and petition, present your requests to God." — Philippians 4:6',
    '"The Lord is near to all who call on Him." — Psalm 145:18',
    '"Pray without ceasing." — 1 Thessalonians 5:17',
    '"Cast all your anxiety on Him because He cares for you." — 1 Peter 5:7',
    '"Call to me and I will answer you." — Jeremiah 33:3',
    '"The righteous cry out, and the Lord hears them." — Psalm 34:17',
    '"Commit your way to the Lord; trust in Him and He will do this." — Psalm 37:5',
  ];

  String get _currentVerse => _verses[_remainingSeconds % _verses.length];

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds;
    _totalSeconds = widget.initialSeconds;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    if (_isCompleted) {
      _resetTimer();
      return;
    }
    setState(() => _isRunning = !_isRunning);
    if (_isRunning) {
      _pulseController.repeat(reverse: true);
      _startCountdown();
    } else {
      _pulseController.stop();
      _pulseController.reset();
      _timer?.cancel();
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _pulseController.stop();
        _pulseController.reset();
        if (mounted) {
          setState(() {
            _isRunning = false;
            _isCompleted = true;
            _remainingSeconds = 0;
          });
          widget.onCompleted?.call();
        }
        return;
      }
      if (mounted) setState(() => _remainingSeconds--);
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    setState(() {
      _remainingSeconds = widget.initialSeconds;
      _isRunning = false;
      _isCompleted = false;
    });
  }

  String get _formattedTime {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _progress =>
      _totalSeconds > 0 ? (_totalSeconds - _remainingSeconds) / _totalSeconds : 0.0;

  @override
  Widget build(BuildContext context) {
    if (widget.showCompact) return _buildCompact();
    return _buildFull();
  }

  Widget _buildCompact() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14243A), Color(0xFF1E1E3A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = _isRunning ? 1.0 + (_pulseController.value * 0.06) : 1.0;
              return Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isCompleted ? AppTheme.gold.withOpacity(0.2) : AppTheme.emerald.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isCompleted ? Icons.check_circle : _isRunning ? Icons.pause : Icons.timer_outlined,
                    color: _isCompleted ? AppTheme.gold : AppTheme.emerald,
                    size: 24,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isCompleted ? 'Prayer Complete! 🎉' : 'Prayer Timer',
                  style: const TextStyle(fontFamily: 'Lora', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  _isCompleted
                      ? 'Amen! Great time with the Lord.'
                      : _isRunning
                          ? 'Praying... $_formattedTime remaining'
                          : 'Focused silent prayer',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppTheme.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formattedTime,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isCompleted ? AppTheme.gold : AppTheme.emerald,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _toggleTimer,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: _isCompleted ? AppTheme.gold : _isRunning ? Colors.orange : AppTheme.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  _isCompleted ? 'Again' : _isRunning ? 'Pause' : 'Start',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFull() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0D2618), Color(0xFF1A3A2A)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.emerald.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: AppTheme.emerald.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = _isRunning ? 1.0 + (_pulseController.value * 0.08) : 1.0;
                return Transform.scale(scale: scale,
                  child: Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isCompleted ? AppTheme.gold.withOpacity(0.15) : AppTheme.emerald.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_isCompleted ? Icons.check_circle : Icons.volunteer_activism,
                      color: _isCompleted ? AppTheme.gold : AppTheme.emerald, size: 30),
                  ),
                );
              },
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_isCompleted ? 'Prayer Complete' : 'Prayer Session',
                style: const TextStyle(fontFamily: 'Lora', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(_isCompleted ? 'God listened to your heart' : 'Be still in His presence',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppTheme.textMuted)),
            ]),
          ]),
          if (_isRunning || _isCompleted)
            IconButton(icon: const Icon(Icons.refresh, color: AppTheme.textMuted, size: 20), onPressed: _resetTimer),
        ]),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (_isRunning ? AppTheme.emerald : AppTheme.gold).withOpacity(0.15)),
              ),
              child: Column(children: [
                Text(_formattedTime, style: TextStyle(fontFamily: 'Inter', fontSize: 52, fontWeight: FontWeight.bold,
                  color: _isCompleted ? AppTheme.gold : _isRunning ? AppTheme.emerald : Colors.white)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress.clamp(0.0, 1.0), minHeight: 4,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(_isCompleted ? AppTheme.gold : AppTheme.emerald),
                  ),
                ),
              ]),
            );
          },
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Icon(Icons.format_quote, color: AppTheme.gold, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(_currentVerse,
              style: const TextStyle(fontFamily: 'Lora', fontSize: 13, fontStyle: FontStyle.italic, color: AppTheme.textSecondary, height: 1.4))),
          ]),
        ),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(
            child: SizedBox(height: 48, child: ElevatedButton.icon(
              onPressed: _toggleTimer,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCompleted ? AppTheme.gold : _isRunning ? Colors.orange : AppTheme.emerald,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
              ),
              icon: Icon(_isCompleted ? Icons.refresh : _isRunning ? Icons.pause : Icons.play_arrow, size: 20),
              label: Text(_isCompleted ? 'Pray Again' : _isRunning ? 'Pause' : 'Start Prayer',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold)),
            )),
          ),
        ]),
      ]),
    );
  }
}

