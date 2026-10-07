import 'dart:convert';
import 'dart:io' show InternetAddress, Platform, SocketException;
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/dio_client.dart';
import 'restriction_store.dart';

/// Live status of the Android-side website protection (local VPN/DNS filter).
class WebsiteProtectionStatus {
  final bool vpnPermissionGranted;
  final bool running;
  final bool wanted;
  final int blockedLookups;
  final bool privateDnsStrict;
  final int totalQueries;
  final String lastHost;
  final String lastError;

  const WebsiteProtectionStatus({
    this.totalQueries = 0,
    this.lastHost = '',
    this.lastError = '',
    this.vpnPermissionGranted = false,
    this.running = false,
    this.wanted = false,
    this.blockedLookups = 0,
    this.privateDnsStrict = false,
  });

  /// Protection is only "active" when Android is really running the filter.
  bool get isActive => running;
}

/// Outcome of checking the Website Protection Key.
class KeyCheck {
  final bool ok;
  final int remaining; // attempts left (-1 = unknown)
  final int lockedSeconds;
  final String? message;
  const KeyCheck({required this.ok, this.remaining = -1, this.lockedSeconds = 0, this.message});
}

/// Wrapper over the native website-blocking channel + the Website Protection
/// Key (stored only as a salted hash in secure storage - never in plain text).
class WebsiteProtectionService {
  WebsiteProtectionService._();
  static final WebsiteProtectionService instance = WebsiteProtectionService._();

  static const MethodChannel _ch = MethodChannel('com.godfident/focus_blocking');
  static const _storage = FlutterSecureStorage();
  static const _kHash = 'website_key_hash';
  static const _kSalt = 'website_key_salt';
  static const _kFails = 'website_key_fails';
  static const _kLockUntil = 'website_key_lock_until';

  bool get supported => Platform.isAndroid;

  // ── Android protection ──────────────────────────────────────────────
  Future<WebsiteProtectionStatus> status() async {
    if (!supported) return const WebsiteProtectionStatus();
    try {
      final m = await _ch.invokeMethod<Map<Object?, Object?>>('websiteStatus');
      if (m == null) return const WebsiteProtectionStatus();
      return WebsiteProtectionStatus(
        vpnPermissionGranted: m['vpnPermissionGranted'] == true,
        running: m['running'] == true,
        wanted: m['wanted'] == true,
        blockedLookups: (m['blockedLookups'] as num?)?.toInt() ?? 0,
        privateDnsStrict: m['privateDnsStrict'] == true,
        totalQueries: (m['totalQueries'] as num?)?.toInt() ?? 0,
        lastHost: (m['lastHost'] ?? '').toString(),
        lastError: (m['lastError'] ?? '').toString(),
      );
    } on PlatformException {
      return const WebsiteProtectionStatus();
    }
  }

  /// Shows Android's VPN consent dialog. True only if the user accepted.
  Future<bool> requestVpnPermission() async {
    if (!supported) return false;
    try {
      return await _ch.invokeMethod<bool>('requestVpnPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> setBlockedDomains(List<String> domains) async {
    if (!supported) return;
    try {
      await _ch.invokeMethod('setBlockedDomains', {'domains': domains});
    } on PlatformException {/* surfaced by status() */}
  }

  Future<void> setBlockedKeywords(List<String> keywords) async {
    if (!supported) return;
    try {
      await _ch.invokeMethod('setBlockedKeywords', {'keywords': keywords});
    } on PlatformException {/* surfaced by status() */}
  }

  /// Starts the filter and VERIFIES it is really running before returning true.
  Future<bool> start(List<String> domains) async {
    if (!supported) return false;
    try {
      await setBlockedDomains(domains);
      await setBlockedKeywords(await RestrictionStore.instance.loadKeywords());
      if (!await requestVpnPermission()) return false;
      final requested = await _ch.invokeMethod<bool>('startWebsiteProtection') ?? false;
      if (!requested) return false;
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if ((await status()).running) return true;
      }
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> stop() async {
    if (!supported) return;
    try {
      await _ch.invokeMethod('stopWebsiteProtection');
    } on PlatformException {/* ignore */}
  }

  /// Website protection is ALWAYS ON while there is at least one protected
  /// site. Call this at launch, on resume and whenever the list changes. It
  /// never shows a dialog: if Android's VPN consent is missing it simply does
  /// nothing and the Website Protection screen offers the "Allow" button.
  Future<void> ensureRunning(List<String> domains) async {
    if (!supported) return;
    await setBlockedDomains(domains);
    final words = await RestrictionStore.instance.loadKeywords();
    await setBlockedKeywords(words);
    final s = await status();
    if (domains.isEmpty && words.isEmpty) {
      if (s.running || s.wanted) await stop();
      return;
    }
    if (s.running || !s.vpnPermissionGranted) return;
    try {
      await _ch.invokeMethod<bool>('startWebsiteProtection');
    } on PlatformException {/* surfaced by status() */}
  }

  /// REAL end-to-end check: ask Android to resolve a protected domain. If the
  /// filter works the lookup must FAIL. Returns a human-readable verdict.
  Future<String> selfTest(String domain) async {
    final before = (await status()).totalQueries;
    String verdict;
    try {
      final r = await InternetAddress.lookup(domain).timeout(const Duration(seconds: 8));
      verdict = r.isEmpty
          ? 'BLOCKED: $domain returned no address.'
          : 'NOT BLOCKED: $domain still resolved to ${r.first.address}.';
    } on SocketException {
      verdict = 'BLOCKED: $domain could not be resolved.';
    } catch (e) {
      verdict = 'Test inconclusive ($e).';
    }
    final after = await status();
    final seen = after.totalQueries - before;
    if (verdict.startsWith('NOT BLOCKED') && seen == 0) {
      verdict += ' Godfident saw no DNS lookup at all, so Android is not sending lookups through the filter '
          '(Private DNS / a browser\u2019s Secure DNS / another VPN is likely taking over).';
    }
    return verdict;
  }

  Future<void> openVpnSettings() async {
    if (!supported) return;
    try {
      await _ch.invokeMethod('openVpnSettings');
    } on PlatformException {/* ignore */}
  }

  // ── Website Protection Key ──────────────────────────────────────────
  // The key lives on the user's ACCOUNT (Django backend), so clearing the
  // app's data or reinstalling cannot remove it. A salted hash is also kept
  // on the phone so the key still works offline. The key is created once;
  // after that the app only ever asks for it.
  static String _hash(String key, String salt) =>
      sha256.convert(utf8.encode('$salt:$key')).toString();

  static Map<String, dynamic> _unwrap(dynamic d) {
    if (d is Map && d['data'] is Map) return Map<String, dynamic>.from(d['data'] as Map);
    if (d is Map) return Map<String, dynamic>.from(d);
    return const {};
  }

  Future<void> _storeLocal(String key) async {
    final rnd = Random.secure();
    final salt = base64UrlEncode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    await _storage.write(key: _kSalt, value: salt);
    await _storage.write(key: _kHash, value: _hash(key, salt));
    await _storage.delete(key: _kFails);
  }

  /// true = a key exists, false = none yet (first time), null = cannot tell
  /// right now (offline and nothing stored on this phone). The UI must NOT
  /// offer "create key" for null, or going offline would be a way round it.
  Future<bool?> hasKey() async {
    if ((await _storage.read(key: _kHash)) != null) return true;
    try {
      final r = await DioClient.instance.get('/api/focus/website-key/');
      return _unwrap(r.data)['has_key'] == true;
    } on DioException {
      return null;
    }
  }

  /// Creates the key (once). Returns null on success or a message to show.
  Future<String?> createKey(String key) async {
    try {
      await DioClient.instance.post('/api/focus/website-key/', data: {'key': key});
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        return 'A key already exists on your account. Enter it to unlock.';
      }
      if (e.response == null) {
        return 'Connect to the internet to create your key. It is saved to your account so that clearing the app cannot remove it.';
      }
      if (e.response?.statusCode == 404) {
        return 'Your server has not been updated for Website Protection yet. Deploy the backend patch first.';
      }
      return friendlyError(e);
    }
    await _storeLocal(key);
    await _storage.delete(key: _kLockUntil);
    return null;
  }

  /// Seconds the key screen stays locked after too many wrong attempts (0 = open).
  Future<int> lockedSeconds() async {
    final until = int.tryParse(await _storage.read(key: _kLockUntil) ?? '') ?? 0;
    final left = until - DateTime.now().millisecondsSinceEpoch;
    return left > 0 ? (left / 1000).ceil() : 0;
  }

  Future<void> _lockFor(int seconds) => _storage.write(
        key: _kLockUntil,
        value: '${DateTime.now().add(Duration(seconds: seconds)).millisecondsSinceEpoch}',
      );

  /// Checks the key. The server is the authority when reachable (its attempt
  /// counter cannot be reset by clearing the app); offline it falls back to
  /// the copy on this phone.
  Future<KeyCheck> verifyKey(String key) async {
    final locked = await lockedSeconds();
    if (locked > 0) return KeyCheck(ok: false, lockedSeconds: locked);
    try {
      final r = await DioClient.instance.post('/api/focus/website-key/verify/', data: {'key': key});
      final m = _unwrap(r.data);
      if (m['ok'] == true) {
        await _storeLocal(key);
        await _storage.delete(key: _kLockUntil);
        return const KeyCheck(ok: true);
      }
      final secs = (m['locked_seconds'] as num?)?.toInt() ?? 0;
      if (secs > 0) await _lockFor(secs);
      return KeyCheck(ok: false, remaining: (m['remaining_attempts'] as num?)?.toInt() ?? -1, lockedSeconds: secs);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 429) {
        final secs = (_unwrap(e.response?.data)['locked_seconds'] as num?)?.toInt() ?? 300;
        await _lockFor(secs);
        return KeyCheck(ok: false, lockedSeconds: secs);
      }
      if (code == 401) return const KeyCheck(ok: false, message: 'Please sign in again.');
      return _verifyLocal(key);
    }
  }

  Future<KeyCheck> _verifyLocal(String key) async {
    final salt = await _storage.read(key: _kSalt);
    final hash = await _storage.read(key: _kHash);
    if (salt == null || hash == null) {
      return const KeyCheck(ok: false, message: 'Connect to the internet once to unlock.');
    }
    if (_hash(key, salt) == hash) {
      await _storage.delete(key: _kFails);
      return const KeyCheck(ok: true);
    }
    final fails = (int.tryParse(await _storage.read(key: _kFails) ?? '') ?? 0) + 1;
    if (fails >= 5) {
      await _lockFor(300);
      await _storage.delete(key: _kFails);
      return const KeyCheck(ok: false, lockedSeconds: 300);
    }
    await _storage.write(key: _kFails, value: '$fails');
    return KeyCheck(ok: false, remaining: 5 - fails);
  }
}
