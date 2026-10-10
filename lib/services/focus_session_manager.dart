import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/focus_repository.dart';
import '../repositories/prayer_repository.dart';
import 'focus_blocking_service.dart';
import 'music_controller.dart';
import 'daily_activity.dart';
import 'notification_service.dart';
import 'restriction_store.dart';

class SessionStart {
  final bool ok;
  final bool blocking; // false = timer only (no apps could be blocked)
  final String? message;
  const SessionStart(this.ok, {this.blocking = false, this.message});
}

class SessionInfo {
  final bool active;
  final DateTime? endAt;
  final DateTime? startedAt;
  final int plannedMinutes;
  final String purpose; // '' | bible | prayer | both
  final bool blocking;

  /// Frozen = paused by the person. The clock does not run and nothing is
  /// blocked, but the session is NOT finished and nags every 10 minutes.
  final bool frozen;
  final Duration frozenLeft;
  const SessionInfo({
    this.active = false,
    this.endAt,
    this.startedAt,
    this.plannedMinutes = 0,
    this.purpose = '',
    this.blocking = false,
    this.frozen = false,
    this.frozenLeft = Duration.zero,
  });

  Duration get left => frozen ? frozenLeft : (endAt == null ? Duration.zero : endAt!.difference(DateTime.now()));
}

/// One place that starts and ends Focus sessions - used by the Focus screen,
/// the Prayer Focus screen and by reminder taps. It keeps the on-phone session
/// (app blocking + timer), the end-of-session notification, and the server
/// records (Focus session, Prayer session) together, so a day of prayer or
/// focus is recorded wherever the session was started from.
class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  /// Bumps whenever a session starts, freezes, resumes, is extended or ends, so
  /// the app-wide timer banner can refresh at once.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);
  void _changed() => changes.value++;
  bool _busyEditing = false; // extending: reconcile() must not read the brief gap as "finished"

  static const _kStartedAt = 'sm_started_at';
  static const _kMinutes = 'sm_minutes';
  static const _kPurpose = 'sm_purpose';
  static const _kSoftEnd = 'sm_soft_end';
  static const _kFocusId = 'focus_backend_session_id';
  static const _kPrayerId = 'sm_prayer_session_id';
  static const _kPending = 'sm_pending_v1';
  static const _kFrozenLeft = 'sm_frozen_left_ms';
  static const _kFrozenBlocking = 'sm_frozen_blocking';
  static const _kElapsed = 'sm_elapsed_before_ms';

  final _focus = FocusBlockingService.instance;

  Future<SessionInfo> info() async {
    final p = await SharedPreferences.getInstance();
    final started = p.getInt(_kStartedAt);
    final minutes = p.getInt(_kMinutes) ?? 0;
    final purpose = p.getString(_kPurpose) ?? '';
    final frozenMs = p.getInt(_kFrozenLeft);
    if (frozenMs != null && started != null) {
      return SessionInfo(
        active: true,
        startedAt: DateTime.fromMillisecondsSinceEpoch(started),
        plannedMinutes: minutes,
        purpose: purpose,
        blocking: false,
        frozen: true,
        frozenLeft: Duration(milliseconds: frozenMs),
      );
    }
    Map<String, dynamic> native = const {'active': false};
    try {
      native = await _focus.getSessionInfo();
    } catch (_) {}
    final nativeActive = native['active'] == true;
    final soft = p.getInt(_kSoftEnd) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nativeActive) {
      final end = (native['endAtMs'] as num?)?.toInt() ?? 0;
      return SessionInfo(
        active: true,
        endAt: end == 0 ? null : DateTime.fromMillisecondsSinceEpoch(end),
        startedAt: started == null ? null : DateTime.fromMillisecondsSinceEpoch(started),
        plannedMinutes: minutes,
        purpose: purpose,
        blocking: true,
      );
    }
    if (soft > nowMs) {
      return SessionInfo(
        active: true,
        endAt: DateTime.fromMillisecondsSinceEpoch(soft),
        startedAt: started == null ? null : DateTime.fromMillisecondsSinceEpoch(started),
        plannedMinutes: minutes,
        purpose: purpose,
        blocking: false,
      );
    }
    return const SessionInfo();
  }

  /// Starts a session. [requireBlocking] = refuse to start unless apps can really
  /// be blocked (the Focus screen); false = fall back to a timer-only session
  /// (Prayer Focus and reminder taps, where praying matters more than blocking).
  Future<SessionStart> start({
    required int minutes,
    String purpose = '',
    bool requireBlocking = false,
    bool allowOnlyOverride = false,
    bool block = true,
    String title = '',
  }) async {
    if ((await info()).active) {
      return const SessionStart(false, message: 'A session is already running.');
    }
    final endAt = DateTime.now().add(Duration(minutes: minutes));
    final p = await SharedPreferences.getInstance();

    final apps = await RestrictionStore.instance.loadApps();
    final allowOnly = allowOnlyOverride || await RestrictionStore.instance.getAllowOnly();
    var blocking = false;
    if (block && (apps.isNotEmpty || allowOnly)) {
      try {
        if (await _focus.isAccessibilityEnabled() || await _focus.hasUsageAccess()) {
          blocking = await _focus.startFocusSession(
            apps.map((a) => a.packageName).toList(),
            endAt: endAt,
            allowOnly: allowOnly,
          );
        }
      } catch (_) {}
    }
    if (!blocking && requireBlocking) {
      return const SessionStart(false,
          message: 'Android did not start the restriction service, so no apps are being blocked.');
    }

    await p.remove(_kFrozenLeft);
    await p.remove(_kFrozenBlocking);
    await p.setInt(_kElapsed, 0);
    await p.setInt(_kStartedAt, DateTime.now().millisecondsSinceEpoch);
    await p.setInt(_kMinutes, minutes);
    await p.setString(_kPurpose, purpose);
    await p.setInt(_kSoftEnd, blocking ? 0 : endAt.millisecondsSinceEpoch);

    // "Your session has ended" - arrives even if the app is closed.
    await NotificationService().scheduleFocusEnd(
      endAt,
      purpose: purpose,
      route: purpose == 'prayer' ? '/prayer/focus' : '/focus',
    );
    // Live countdown in the notification shade / lock screen.
    await NotificationService().showSessionTimer(
      endAt: endAt,
      purpose: purpose,
      route: purpose == 'prayer' ? '/prayer/focus' : '/focus',
    );

    // Server records, best effort (the session itself never depends on them).
    try {
      final s = await FocusRepository().startSession(purpose: purpose);
      await p.setInt(_kFocusId, s.id);
    } catch (_) {}
    if (purpose == 'prayer' || purpose == 'both') {
      try {
        final ps = await PrayerRepository().createSession(
          title: title.isEmpty ? 'Prayer focus' : title,
          plannedMinutes: minutes,
        );
        await p.setInt(_kPrayerId, ps.id);
      } catch (_) {}
    }
    // Calm music for the session (last song played, else the ringtone, else a bundled track).
    MusicController.instance.startForSession();
    _changed();
    return SessionStart(true, blocking: blocking);
  }

  /// Pauses the session. It is NOT finished: the clock stops, blocking is
  /// lifted, and every 10 minutes a notification says it is still unfinished.
  Future<bool> freeze() async {
    final i = await info();
    if (!i.active || i.frozen) return false;
    final p = await SharedPreferences.getInstance();
    final left = i.left.isNegative ? Duration.zero : i.left;
    final started = p.getInt(_kStartedAt) ?? DateTime.now().millisecondsSinceEpoch;
    final elapsed = (p.getInt(_kElapsed) ?? 0) + (DateTime.now().millisecondsSinceEpoch - started);
    try {
      await _focus.stopFocusSession();
    } catch (_) {}
    await p.setInt(_kElapsed, elapsed);
    await p.setBool(_kFrozenBlocking, i.blocking);
    await p.setInt(_kFrozenLeft, left.inMilliseconds);
    await p.setInt(_kSoftEnd, 0);
    await NotificationService().cancelFocusEnd();
    await NotificationService().scheduleFocusNags(
      left: left,
      route: i.purpose == 'prayer' ? '/prayer/focus' : '/focus',
    );
    await NotificationService().showSessionTimer(
      endAt: DateTime.now(),
      purpose: i.purpose,
      route: i.purpose == 'prayer' ? '/prayer/focus' : '/focus',
      frozen: true,
      frozenLeft: left,
    );
    MusicController.instance.pauseForFreeze();
    _changed();
    return true;
  }

  /// Continues a frozen session with the time that was left.
  Future<bool> resume() async {
    final p = await SharedPreferences.getInstance();
    final leftMs = p.getInt(_kFrozenLeft);
    if (leftMs == null) return false;
    final purpose = p.getString(_kPurpose) ?? '';
    final wasBlocking = p.getBool(_kFrozenBlocking) ?? false;
    final endAt = DateTime.now().add(Duration(milliseconds: leftMs));
    var blocking = false;
    if (wasBlocking) {
      try {
        final apps = await RestrictionStore.instance.loadApps();
        final allowOnly = await RestrictionStore.instance.getAllowOnly();
        blocking = await _focus.startFocusSession(
          apps.map((a) => a.packageName).toList(),
          endAt: endAt,
          allowOnly: allowOnly,
        );
      } catch (_) {}
    }
    await p.setInt(_kStartedAt, DateTime.now().millisecondsSinceEpoch);
    await p.setInt(_kSoftEnd, blocking ? 0 : endAt.millisecondsSinceEpoch);
    await p.remove(_kFrozenLeft);
    await p.remove(_kFrozenBlocking);
    await NotificationService().cancelFocusNags();
    await NotificationService().scheduleFocusEnd(
      endAt,
      purpose: purpose,
      route: purpose == 'prayer' ? '/prayer/focus' : '/focus',
    );
    await NotificationService().showSessionTimer(
      endAt: endAt,
      purpose: purpose,
      route: purpose == 'prayer' ? '/prayer/focus' : '/focus',
    );
    MusicController.instance.resumeAfterFreeze();
    _changed();
    return true;
  }

  /// Adds [minutes] to the running (or frozen) session. The session counts as
  /// finished only after the longer time has been spent.
  Future<bool> extend(int minutes) async {
    if (minutes <= 0) return false;
    final i = await info();
    if (!i.active) return false;
    _busyEditing = true;
    try {
      final p = await SharedPreferences.getInstance();
      final purpose = p.getString(_kPurpose) ?? '';
      final route = purpose == 'prayer' ? '/prayer/focus' : '/focus';
      await p.setInt(_kMinutes, (p.getInt(_kMinutes) ?? 0) + minutes);
      if (i.frozen) {
        final left = i.frozenLeft + Duration(minutes: minutes);
        await p.setInt(_kFrozenLeft, left.inMilliseconds);
        await NotificationService().scheduleFocusNags(left: left, route: route);
        await NotificationService().showSessionTimer(
            endAt: DateTime.now(), purpose: purpose, route: route, frozen: true, frozenLeft: left);
      } else {
        final endAt = (i.endAt ?? DateTime.now()).add(Duration(minutes: minutes));
        if (i.blocking) {
          try {
            final apps = await RestrictionStore.instance.loadApps();
            final allowOnly = await RestrictionStore.instance.getAllowOnly();
            // Starting again with a later end time replaces the running one (no gap).
            await _focus.startFocusSession(apps.map((a) => a.packageName).toList(), endAt: endAt, allowOnly: allowOnly);
          } catch (_) {}
        } else {
          await p.setInt(_kSoftEnd, endAt.millisecondsSinceEpoch);
        }
        await NotificationService().scheduleFocusEnd(endAt, purpose: purpose, route: route);
        await NotificationService().showSessionTimer(endAt: endAt, purpose: purpose, route: route);
      }
    } finally {
      _busyEditing = false;
    }
    _changed();
    return true;
  }

  /// Ends the running session now ([early] = the person pressed End).
  Future<void> end({bool early = true}) async {
    await _finish(early: early);
  }

  /// Call when a screen opens or the app resumes: a session whose time ran out
  /// while the app was closed is recorded as completed, and unsent records retry.
  Future<void> reconcile() async {
    if (_busyEditing) return;
    final p = await SharedPreferences.getInstance();
    if (p.getInt(_kStartedAt) != null && !(await info()).active) {
      await _finish(early: false, alreadyStopped: true);
    }
    await _flushPending();
  }

  Future<void> _finish({required bool early, bool alreadyStopped = false}) async {
    final p = await SharedPreferences.getInstance();
    final started = p.getInt(_kStartedAt);
    if (started == null) {
      if (!alreadyStopped) {
        try {
          await _focus.stopFocusSession();
        } catch (_) {}
      }
      return;
    }
    final planned = p.getInt(_kMinutes) ?? 0;
    final purpose = p.getString(_kPurpose) ?? '';
    final focusId = p.getInt(_kFocusId);
    final prayerId = p.getInt(_kPrayerId);

    if (!alreadyStopped) {
      try {
        await _focus.stopFocusSession();
      } catch (_) {}
    }
    await NotificationService().cancelFocusEnd();
    await NotificationService().cancelFocusNags();
    await NotificationService().cancelSessionTimer();
    MusicController.instance.endSessionMusic();

    final wasFrozen = p.getInt(_kFrozenLeft) != null;
    final elapsedMs = (p.getInt(_kElapsed) ?? 0) + (wasFrozen ? 0 : DateTime.now().millisecondsSinceEpoch - started);
    var seconds = (elapsedMs / 1000).round();
    final plannedSec = planned * 60;
    // Only a session that ran its WHOLE time counts. Ending early records nothing as done.
    final completed = !early;
    if (completed) seconds = plannedSec;

    if (completed) {
      if (purpose == 'prayer' || purpose == 'both') DailyActivity.markPrayed();
      if (purpose == 'bible' || purpose == 'both') DailyActivity.markRead();
    }
    await p.remove(_kStartedAt);
    await p.remove(_kMinutes);
    await p.remove(_kPurpose);
    await p.remove(_kSoftEnd);
    await p.remove(_kFocusId);
    await p.remove(_kPrayerId);
    await p.remove(_kFrozenLeft);
    await p.remove(_kFrozenBlocking);
    await p.remove(_kElapsed);
    await p.remove('focus_active_minutes');
    await p.remove('focus_active_purpose');

    final ops = <Map<String, dynamic>>[
      if (focusId != null)
        {'t': 'focus', 'id': focusId, 'min': (seconds / 60).ceil(), 's': completed ? 'completed' : 'interrupted'},
      if (prayerId != null) {'t': 'prayer', 'id': prayerId, 'sec': completed ? seconds : 0}, // 0 = delete: unfinished prayer is not recorded
    ];
    await _queue(ops);
    _changed();
    await _flushPending();
  }

  Future<void> _queue(List<Map<String, dynamic>> ops) async {
    if (ops.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final list = List<String>.from(p.getStringList(_kPending) ?? []);
    list.addAll(ops.map(jsonEncode));
    await p.setStringList(_kPending, list);
  }

  Future<void> _flushPending() async {
    final p = await SharedPreferences.getInstance();
    final list = List<String>.from(p.getStringList(_kPending) ?? []);
    if (list.isEmpty) return;
    final left = <String>[];
    for (final raw in list) {
      try {
        final o = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        if (o['t'] == 'focus') {
          await FocusRepository().endSession(o['id'] as int, durationMinutes: o['min'] as int, status: o['s'] as String);
        } else if (o['t'] == 'prayer') {
          final sec = o['sec'] as int;
          if (sec >= 60) {
            await PrayerRepository().endSession(o['id'] as int, durationSeconds: sec);
          } else {
            await PrayerRepository().deleteSession(o['id'] as int); // under a minute does not count
          }
        }
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == 400 || code == 404) continue; // gone / invalid: retrying cannot help
        left.add(raw);
      } catch (e) {
        if (kDebugMode) print('session sync failed: $e');
        left.add(raw);
      }
    }
    await p.setStringList(_kPending, left);
  }
}
