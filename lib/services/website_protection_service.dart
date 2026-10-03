import 'dart:convert';
import 'dart:io' show InternetAddress, Platform, SocketException;
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  /// Starts the filter and VERIFIES it is really running before returning true.
  Future<bool> start(List<String> domains) async {
    if (!supported) return false;
    try {
      await setBlockedDomains(domains);
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
  static String _hash(String key, String salt) =>
      sha256.convert(utf8.encode('$salt:$key')).toString();

  Future<bool> hasKey() async => (await _storage.read(key: _kHash)) != null;

  Future<void> setKey(String key) async {
    final rnd = Random.secure();
    final salt = base64UrlEncode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    await _storage.write(key: _kSalt, value: salt);
    await _storage.write(key: _kHash, value: _hash(key, salt));
    await _storage.delete(key: _kFails);
    await _storage.delete(key: _kLockUntil);
  }

  /// Seconds the key screen stays locked after too many wrong attempts (0 = open).
  Future<int> lockedSeconds() async {
    final until = int.tryParse(await _storage.read(key: _kLockUntil) ?? '') ?? 0;
    final left = until - DateTime.now().millisecondsSinceEpoch;
    return left > 0 ? (left / 1000).ceil() : 0;
  }

  Future<bool> verifyKey(String key) async {
    if (await lockedSeconds() > 0) return false;
    final salt = await _storage.read(key: _kSalt);
    final hash = await _storage.read(key: _kHash);
    if (salt == null || hash == null) return false;
    if (_hash(key, salt) == hash) {
      await _storage.delete(key: _kFails);
      return true;
    }
    final fails = (int.tryParse(await _storage.read(key: _kFails) ?? '') ?? 0) + 1;
    await _storage.write(key: _kFails, value: '$fails');
    if (fails >= 5) {
      await _storage.write(
        key: _kLockUntil,
        value: '${DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch}',
      );
      await _storage.delete(key: _kFails);
    }
    return false;
  }

  Future<int> remainingAttempts() async =>
      5 - (int.tryParse(await _storage.read(key: _kFails) ?? '') ?? 0);
}
