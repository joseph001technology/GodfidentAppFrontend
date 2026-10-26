import 'dart:async';
import 'package:flutter/foundation.dart';
import 'focus_session_manager.dart';

/// One measurement of the current session: what it is ([info]) and the instant
/// it was measured ([at]). Every screen that shows the countdown reads the same
/// snapshot, so the Prayer page, the Focus page and the bottom banner always
/// show exactly the same time.
@immutable
class SessionSnapshot {
  final SessionInfo info;
  final DateTime at;
  const SessionSnapshot(this.info, this.at);

  /// A session exists (running or frozen).
  bool get active => info.active;
  bool get frozen => info.active && info.frozen;
  bool get running => info.active && !info.frozen;

  /// Time left at the moment of this snapshot (the frozen time while frozen).
  Duration get left {
    if (!info.active) return Duration.zero;
    if (info.frozen) return info.frozenLeft;
    final end = info.endAt;
    if (end == null) return Duration.zero;
    final d = end.difference(at);
    return d.isNegative ? Duration.zero : d;
  }

  /// 0..1: how much of the planned time has passed.
  double get progress {
    final total = info.plannedMinutes * 60;
    if (!info.active || total <= 0) return 0;
    return (1 - left.inSeconds / total).clamp(0.0, 1.0).toDouble();
  }
}

/// "5:07", "12:30" or "1:05:00".
String formatSessionLeft(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = sec.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// The one clock of the current session. It ticks once a second for ALL screens
/// that listen to it, re-reads the session whenever it changes (started, frozen,
/// resumed, extended, ended) and every few seconds in case it was changed from
/// outside the app (the notification card buttons). It only runs while at least
/// one screen is listening.
class SessionTicker extends ValueNotifier<SessionSnapshot> {
  SessionTicker._() : super(SessionSnapshot(const SessionInfo(), DateTime.now()));
  static final SessionTicker instance = SessionTicker._();

  final _sm = SessionManager.instance;
  Timer? _timer;
  int _n = 0;
  bool _reading = false;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (_timer == null) _start();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) _stop();
  }

  void _start() {
    _sm.changes.addListener(_onChanged);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _reload();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _sm.changes.removeListener(_onChanged);
  }

  void _onChanged() => _reload();

  void _tick() {
    _n++;
    final v = value;
    final end = v.info.endAt;
    if (v.running && end != null && !end.isAfter(DateTime.now())) {
      _reload(reconcile: true); // time is up: record it and clear the card everywhere
      return;
    }
    if (_n % 5 == 0) {
      _reload(); // catches sessions started, frozen or ended from elsewhere
      return;
    }
    value = SessionSnapshot(v.info, DateTime.now());
  }

  /// Reads the session again right now (call after you change it).
  Future<void> refresh() => _reload();

  Future<void> _reload({bool reconcile = false}) async {
    if (_reading) return;
    _reading = true;
    try {
      if (reconcile) await _sm.reconcile();
      final info = await _sm.info();
      value = SessionSnapshot(info, DateTime.now());
    } catch (_) {
      // Keep showing the last good reading.
    } finally {
      _reading = false;
    }
  }
}
