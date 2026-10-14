import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// One waiting Focus session (see FocusQueue.kt). Oldest first; at most 3 wait.
class QueuedSession {
  final String route;
  final String name;
  final int minutes;
  final String purpose;
  const QueuedSession({required this.route, required this.name, required this.minutes, required this.purpose});
}

/// The "now playing" style session card, the focus queue and the background
/// guardian, all of which live in native Android code so they keep working
/// when the app is closed.
class NativeSession {
  NativeSession._();
  static const _ch = MethodChannel('com.godfident/focus_blocking');

  static Future<bool> show({
    required String name,
    required String purposeLabel,
    required DateTime startedAt,
    required DateTime endAt,
    required Duration total,
    required String route,
    bool frozen = false,
    Duration frozenLeft = Duration.zero,
    Uint8List? art,
  }) async {
    try {
      return await _ch.invokeMethod<bool>('showSession', {
            'name': name,
            'purposeLabel': purposeLabel,
            'startedAtMs': startedAt.millisecondsSinceEpoch,
            'endAtMs': endAt.millisecondsSinceEpoch,
            'totalMs': total.inMilliseconds,
            'frozen': frozen,
            'frozenLeftMs': frozenLeft.inMilliseconds,
            'route': route,
            if (art != null) 'art': art,
          }) ??
          false;
    } catch (e) {
      if (kDebugMode) print('NativeSession.show failed: $e');
      return false;
    }
  }

  /// [advance] = the session is over, so ring the oldest waiting one.
  static Future<void> hide({bool advance = false}) async {
    try {
      await _ch.invokeMethod('hideSession', {'advance': advance});
    } catch (_) {}
  }

  static Future<List<QueuedSession>> queue() async {
    try {
      final r = await _ch.invokeMethod<List<Object?>>('queueList') ?? const [];
      return [
        for (final e in r)
          if (e is Map)
            QueuedSession(
              route: '${e['route'] ?? ''}',
              name: '${e['name'] ?? ''}',
              minutes: (e['minutes'] as num?)?.toInt() ?? 30,
              purpose: '${e['purpose'] ?? ''}',
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> queueAdd(String route) async {
    try {
      await _ch.invokeMethod('queueAdd', {'route': route});
    } catch (_) {}
  }

  static Future<void> queueRemove(int index) async {
    try {
      await _ch.invokeMethod('queueRemove', {'index': index});
    } catch (_) {}
  }

  // ── background guardian ─────────────────────────────────────────
  static Future<void> ensureGuardian() async {
    try {
      await _ch.invokeMethod('ensureGuardian');
    } catch (_) {}
  }

  static Future<bool> guardianEnabled() async {
    try {
      return await _ch.invokeMethod<bool>('guardianEnabled') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setGuardian(bool on) async {
    try {
      await _ch.invokeMethod('setGuardian', {'enabled': on});
    } catch (_) {}
  }

  /// What [openAutostartSettings] managed to open.
  /// [level]: 2 = the maker's own auto-start / background page, 1 = Android's
  /// battery-optimisation list, 0 = only Godfident's App info page.
  static Future<({int level, String target})> openAutostart() async {
    try {
      final r = '${await _ch.invokeMethod<dynamic>('openAutostartSettings') ?? '0|appinfo'}';
      final i = r.indexOf('|');
      final code = int.tryParse(i < 0 ? r : r.substring(0, i)) ?? 0;
      return (level: code, target: i < 0 ? '' : r.substring(i + 1));
    } catch (_) {
      return (level: 0, target: 'error');
    }
  }

  static Future<int> openAutostartSettings() async => (await openAutostart()).level;

  /// Lower-case phone maker, e.g. "realme", "tecno", "samsung".
  static Future<String> manufacturer() async {
    try {
      return (await _ch.invokeMethod<String>('manufacturer')) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Opens the phone's own Digital Wellbeing / app timers (true if it opened that app).
  static Future<bool> openWellbeing() async {
    try {
      return await _ch.invokeMethod<bool>('openWellbeing') ?? false;
    } catch (_) {
      return false;
    }
  }
}
