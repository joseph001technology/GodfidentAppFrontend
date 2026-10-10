import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ringing alarms that run in a native Android foreground service (see
/// AlarmRingService.kt). They play on the ALARM audio stream until stopped, so
/// another notification or the volume keys cannot silence them.
class NativeAlarm {
  NativeAlarm._();
  static const _ch = MethodChannel('com.godfident/focus_blocking');

  /// [sound]: "raw:godfident_bell" for a bundled tone, a content:// URI for a
  /// song on the phone, or "" for the phone's alarm tone.
  static Future<bool> schedule({
    required int id,
    required DateTime when,
    Duration repeat = Duration.zero,
    required String title,
    required String body,
    required String route,
    required String sound,
    int maxSeconds = 120,
    String startLabel = '',
    bool ring = true,
    String skipKey = '',
  }) async {
    try {
      final ok = await _ch.invokeMethod<bool>('scheduleAlarm', {
        'id': id,
        'whenMs': when.millisecondsSinceEpoch,
        'repeatMs': repeat.inMilliseconds,
        'title': title,
        'body': body,
        'route': route,
        'sound': sound,
        'maxSeconds': maxSeconds,
        'startLabel': startLabel,
        'ring': ring,
        'skipKey': skipKey,
      });
      return ok ?? false;
    } catch (e) {
      if (kDebugMode) print('NativeAlarm.schedule failed: $e');
      return false;
    }
  }

  /// Re-arms every stored alarm. Alarms that came due while the phone was off
  /// ring if they are under an hour late, otherwise a "Missed" notification is shown.
  static Future<void> rearm() async {
    try {
      await _ch.invokeMethod('rearmAlarms');
    } catch (_) {}
  }

  /// Plays a ringtone sample WITHOUT touching the music player (music is only ducked).
  static Future<bool> previewSound(String sound) async {
    try {
      return await _ch.invokeMethod<bool>('previewSound', {'sound': sound}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopPreview() async {
    try {
      await _ch.invokeMethod('stopPreview');
    } catch (_) {}
  }

  static Future<void> cancel(int id) async {
    try {
      await _ch.invokeMethod('cancelAlarm', {'id': id});
    } catch (_) {}
  }

  /// Stops a ringing alarm sound (Start / opened from the alarm).
  static Future<void> stopSound() async {
    try {
      await _ch.invokeMethod('stopAlarmSound');
    } catch (_) {}
  }

  /// Route of an alarm that launched the app from a cold start (once).
  static Future<String?> launchRoute() async {
    try {
      return await _ch.invokeMethod<String>('getLaunchRoute');
    } catch (_) {
      return null;
    }
  }

  /// Registers [onRoute] for alarms tapped while the app is already running.
  static void listen(void Function(String route) onRoute) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmRoute' && call.arguments is String) {
        onRoute(call.arguments as String);
      }
      return null;
    });
  }
}
