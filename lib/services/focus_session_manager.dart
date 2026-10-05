import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/focus_repository.dart';
import '../repositories/prayer_repository.dart';
import 'focus_blocking_service.dart';
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
  const SessionInfo({
    this.active = false,
    this.endAt,
    this.startedAt,
    this.plannedMinutes = 0,
    this.purpose = '',
    this.blocking = false,
  });

  Duration get left => endAt == null ? Duration.zero : endAt!.difference(DateTime.now());
}

/// One place that starts and ends Focus sessions - used by the Focus screen,
/// the Prayer Focus screen and by reminder taps. It keeps the on-phone session
/// (app blocking + timer), the end-of-session notification, and the server
/// records (Focus session, Prayer session) together, so a day of prayer or
/// focus is recorded wherever the session was started from.
class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  static const _kStartedAt = 'sm_started_at';
  static const _kMinutes = 'sm_minutes';
  static const _kPurpose = 'sm_purpose';
  static const _kSoftEnd = 'sm_soft_end';
  static const _kFocusId = 'focus_backend_session_id';
  static const _kPrayerId = 'sm_prayer_session_id';
  static const _kPending = 'sm_pending_v1';

  final _focus = FocusBlockingService.instance;

  Future<SessionInfo> info() async {
    final p = await SharedPreferences.getInstance();
    final started = p.getInt(_kStartedAt);
    final minutes = p.getInt(_kMinutes) ?? 0;
    final purpose = p.getString(_kPurpose) ?? '';
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
    return SessionStart(true, blocking: blocking);
  }

  /// Ends the running session now ([early] = the person pressed End).
  Future<void> end({bool early = true}) async {
    await _finish(early: early);
  }

  /// Call when a screen opens or the app resumes: a session whose time ran out
  /// while the app was closed is recorded as completed, and unsent records retry.
  Future<void> reconcile() async {
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

    var seconds = ((DateTime.now().millisecondsSinceEpoch - started) / 1000).round();
    final plannedSec = planned * 60;
    if (!early || seconds > plannedSec) seconds = plannedSec; // finished by itself
    final completed = !early || seconds >= plannedSec - 5;

    await p.remove(_kStartedAt);
    await p.remove(_kMinutes);
    await p.remove(_kPurpose);
    await p.remove(_kSoftEnd);
    await p.remove(_kFocusId);
    await p.remove(_kPrayerId);
    await p.remove('focus_active_minutes');
    await p.remove('focus_active_purpose');

    final ops = <Map<String, dynamic>>[
      if (focusId != null)
        {'t': 'focus', 'id': focusId, 'min': (seconds / 60).ceil(), 's': completed ? 'completed' : 'interrupted'},
      if (prayerId != null) {'t': 'prayer', 'id': prayerId, 'sec': seconds},
    ];
    await _queue(ops);
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
