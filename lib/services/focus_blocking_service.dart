import 'dart:io' show Platform;
import 'package:flutter/services.dart';

/// A real, installed app that can be chosen for the App Restrictions list.
class InstalledApp {
  final String packageName;
  final String label;
  final Uint8List? icon;

  const InstalledApp({required this.packageName, required this.label, this.icon});

  factory InstalledApp.fromMap(Map<Object?, Object?> map) {
    return InstalledApp(
      packageName: map['packageName'] as String? ?? '',
      label: map['label'] as String? ?? '',
      icon: map['icon'] as Uint8List?,
    );
  }
}

/// Dart-side wrapper around the native `com.godfident/focus_blocking`
/// method channel (see android/.../MainActivity.kt and
/// FocusBlockingService.kt for the real enforcement logic).
///
/// This is Android-only for now — every method safely no-ops (or returns
/// an empty/false/zero default) on iOS rather than throwing, so screens
/// that call this don't need to scatter `Platform.isAndroid` checks
/// everywhere. The iOS "soft" overlay version is a separate, later piece
/// of work; when that exists, this class is the natural place to branch
/// on platform and call into it instead.
///
/// IMPORTANT — this does not replace the `focus` Django app's
/// BlockedApp/FocusSession models. Those remain the source of truth for
/// *which* apps the user has chosen to restrict (synced from the backend,
/// shown in the App Restrictions screen); this service is purely the
/// on-device enforcement mechanism once a session starts. Call
/// `startFocusSession` with the package names resolved from that list.
class FocusBlockingService {
  FocusBlockingService._();
  static final FocusBlockingService instance = FocusBlockingService._();

  static const MethodChannel _channel = MethodChannel('com.godfident/focus_blocking');

  bool get _supported => Platform.isAndroid;

  /// Whether the special "Usage access" permission has been granted.
  /// There is no runtime permission dialog for this on Android — if this
  /// returns false, call [requestUsageAccess] to deep-link the user to the
  /// right Settings screen, and re-check when the app resumes.
  Future<bool> hasUsageAccess() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens Settings > Apps > Special app access > Usage access. The user
  /// has to manually find and enable Godfident there — Android doesn't
  /// allow a simpler flow for this permission on purpose.
  Future<void> requestUsageAccess() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('requestUsageAccess');
    } on PlatformException {
      // ignore — nothing meaningful to recover from here
    }
  }

  /// Real installed, launchable apps on the device, for the "choose which
  /// apps to restrict" screen. Returns an empty list on iOS or on any
  /// platform channel failure — screens should treat that as "nothing to
  /// show yet", not as an error state.
  Future<List<InstalledApp>> getInstalledApps() async {
    if (!_supported) return const [];
    try {
      final result = await _channel.invokeMethod<List<Object?>>('getInstalledApps');
      if (result == null) return const [];
      return result
          .whereType<Map<Object?, Object?>>()
          .map(InstalledApp.fromMap)
          .toList();
    } on PlatformException {
      return const [];
    }
  }

  /// Starts real enforcement. [endAt] lets the native service end the session
  /// by itself (even if Godfident is closed or offline). With [allowOnly] every
  /// app except Godfident, the launcher, dialer, keyboard and Settings is sent
  /// back to Godfident. Returns false - and starts nothing - if Usage Access
  /// is missing, so the UI never reports a restriction that is not active.
  Future<bool> startFocusSession(
    List<String> blockedPackages, {
    DateTime? endAt,
    bool allowOnly = false,
  }) async {
    if (!_supported) return false;
    // Accessibility blocks instantly; usage access alone is only a weak fallback.
    if (!await isAccessibilityEnabled() && !await hasUsageAccess()) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('startFocusSession', {
            'blockedPackages': blockedPackages,
            'endAtMs': endAt?.millisecondsSinceEpoch ?? 0,
            'allowOnly': allowOnly,
          }) ??
          false;
      if (!ok) return false;
      // Verify, don't assume.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return await isSessionActive();
    } on PlatformException {
      return false;
    }
  }

  /// Native session state: {active, endAtMs, allowOnly, attempts}.
  Future<Map<String, dynamic>> getSessionInfo() async {
    if (!_supported) return const {'active': false};
    try {
      final r = await _channel.invokeMethod<Map<Object?, Object?>>('getSessionInfo');
      return r?.map((k, v) => MapEntry(k.toString(), v)) ?? const {'active': false};
    } on PlatformException {
      return const {'active': false};
    }
  }

  /// Stops the foreground service — call this when a Focus session ends,
  /// whether it completed naturally or the user ended it early.
  Future<bool> stopFocusSession() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('stopFocusSession') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// True if the native service is currently actively enforcing a session
  /// — useful on app resume/cold start to reconcile Dart-side state with
  /// whatever's actually still running natively.
  Future<bool> isSessionActive() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isSessionActive') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// How many times a blocked app was opened during the current/last
  /// session — matches the "Blocked Attempts Log" counter from the
  /// original Focus Mode design.
  Future<int> getBlockedAttemptCount() async {
    if (!_supported) return 0;
    try {
      return await _channel.invokeMethod<int>('getBlockedAttemptCount') ?? 0;
    } on PlatformException {
      return 0;
    }
  }

  /// The label of the most recently blocked app (e.g. "TikTok"), or null
  /// if nothing's been blocked since the last time this was read. Reading
  /// this clears it natively, so call it once — e.g. from an
  /// AppLifecycleState.resumed listener — and show a "You tried to open
  /// TikTok during Focus Mode" message if it's non-null, rather than
  /// polling it repeatedly.
  Future<String?> getLastBlockedApp() async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<String>('getLastBlockedApp');
    } on PlatformException {
      return null;
    }
  }

  // ── Accessibility (instant, reliable blocking) ───────────────────────
  Future<bool> isAccessibilityEnabled() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException {/* ignore */}
  }

  Future<int> sdkInt() async {
    if (!_supported) return 0;
    try {
      return await _channel.invokeMethod<int>('getSdkInt') ?? 0;
    } on PlatformException {
      return 0;
    }
  }
}
