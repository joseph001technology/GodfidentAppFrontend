import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/scheduled_focus.dart';
import '../../services/native_session.dart';
import '../../services/session_ticker.dart';

/// "Up next": the sessions waiting for the current one.
///
/// The first one is always shown, with all its details and a Start button.
/// "See all" opens the others, each with its own details. A session only waits
/// here behind a running (or frozen) session or behind others already waiting;
/// with nothing in the way it is started, or held as a frozen session instead.
class FocusQueueCard extends StatefulWidget {
  final List<QueuedSession> queue;

  /// The person's scheduled sessions by id, to show the time each one was set for.
  final Map<int, ScheduledFocus> schedules;
  final bool busy;
  final Future<void> Function(int index) onStart;
  final Future<void> Function(int index) onRemove;

  const FocusQueueCard({
    super.key,
    required this.queue,
    required this.schedules,
    required this.busy,
    required this.onStart,
    required this.onRemove,
  });

  @override
  State<FocusQueueCard> createState() => _FocusQueueCardState();
}

class _FocusQueueCardState extends State<FocusQueueCard> {
  static const _max = 3; // FocusQueue.MAX on the phone side
  bool _all = false;

  String _clock(DateTime t) => TimeOfDay.fromDateTime(t).format(context);

  String _waiting(DateTime? since) {
    if (since == null) return 'Waiting in the queue';
    final m = DateTime.now().difference(since).inMinutes;
    if (m < 1) return 'Just added';
    if (m < 60) return 'Waiting $m min';
    final h = m ~/ 60;
    final r = m % 60;
    return 'Waiting $h h${r == 0 ? '' : ' $r min'}';
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.queue;
    if (q.isEmpty) return const SizedBox.shrink();
    final shown = _all ? q.length : 1;

    return ValueListenableBuilder<SessionSnapshot>(
      valueListenable: SessionTicker.instance,
      builder: (context, snap, _) {
        // When each one should begin: after what is running now, then one after the other.
        DateTime? startsAt(int i) {
          if (!snap.running) return i == 0 && !snap.active ? snap.at : null; // frozen: nobody knows when
          var t = snap.at.add(snap.left);
          for (var k = 0; k < i; k++) {
            t = t.add(Duration(minutes: q[k].minutes));
          }
          return t;
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          decoration: BoxDecoration(
            color: AppTheme.navySurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('UP NEXT  ·  ${q.length} of $_max waiting',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppTheme.textMuted)),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                snap.frozen
                    ? 'These wait for your frozen session. Only 3 can wait; a fourth replaces the oldest.'
                    : 'These start after the current session. Only 3 can wait; a fourth replaces the oldest.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < shown; i++) ...[
              if (i > 0) Divider(height: 18, color: AppTheme.navyOutline),
              _item(i, q[i], startsAt(i), snap),
            ],
            if (q.length > 1)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _all = !_all),
                  child: Text(_all ? 'Show less' : 'See all ${q.length}'),
                ),
              ),
          ]),
        );
      },
    );
  }

  Widget _item(int i, QueuedSession s, DateTime? startsAt, SessionSnapshot snap) {
    final sched = s.startId == 0 ? null : widget.schedules[s.startId];
    final purpose = ScheduledFocus.purposes[s.purpose];
    final details = <(IconData, String)>[
      (Icons.timer_outlined, '${s.minutes} min${purpose != null ? ' · $purpose' : ''}'),
      if (sched != null) (Icons.event_repeat_outlined, 'Set for ${sched.timeLabel} · ${sched.repeatLabel}'),
      (Icons.hourglass_empty_rounded, _waiting(s.queuedAt)),
      if (startsAt != null)
        (
          Icons.schedule_rounded,
          i == 0 && !snap.active
              ? 'Ready now'
              : 'Starts about ${_clock(startsAt)}, ends about ${_clock(startsAt.add(Duration(minutes: s.minutes)))}',
        ),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppTheme.navyVariant, borderRadius: BorderRadius.circular(13)),
          child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.textPrimary)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(s.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary)),
          ),
        ),
        IconButton(
          icon: Icon(Icons.close_rounded, color: AppTheme.textMuted),
          tooltip: 'Remove from queue',
          visualDensity: VisualDensity.compact,
          onPressed: widget.busy ? null : () => widget.onRemove(i),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.only(left: 36, right: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final d in details)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(d.$1, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Expanded(child: Text(d.$2, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
              ]),
            ),
          if (i == 0) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.busy ? null : () => widget.onStart(0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.inkNavy,
                  minimumSize: const Size(0, 44),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(snap.active ? 'Start now' : 'Start'),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ]),
      ),
    ]);
  }
}
