import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/dio_client.dart';

/// One restricted app, saved on the device first (so it works offline) and
/// mirrored to the Django backend when a connection is available.
class RestrictedApp {
  final String packageName;
  final String label;
  final int? backendId;
  const RestrictedApp({required this.packageName, required this.label, this.backendId});

  RestrictedApp withId(int? id) => RestrictedApp(packageName: packageName, label: label, backendId: id);

  Map<String, dynamic> toJson() => {'p': packageName, 'l': label, 'id': backendId};
  factory RestrictedApp.fromJson(Map<String, dynamic> j) =>
      RestrictedApp(packageName: j['p'] as String, label: j['l'] as String? ?? '', backendId: j['id'] as int?);
}

class RestrictedSite {
  final String domain;
  final int? backendId;
  const RestrictedSite({required this.domain, this.backendId});

  RestrictedSite withId(int? id) => RestrictedSite(domain: domain, backendId: id);

  Map<String, dynamic> toJson() => {'d': domain, 'id': backendId};
  factory RestrictedSite.fromJson(Map<String, dynamic> j) =>
      RestrictedSite(domain: j['d'] as String, backendId: j['id'] as int?);
}

/// Offline-first persistence for the restriction configuration.
class RestrictionStore {
  RestrictionStore._();
  static final RestrictionStore instance = RestrictionStore._();

  static const _kApps = 'restricted_apps_v1';
  static const _kSites = 'restricted_sites_v1';
  static const _kDeleteApps = 'pending_delete_apps_v1';
  static const _kDeleteSites = 'pending_delete_sites_v1';
  static const _kAllowOnly = 'focus_allow_only_v1';
  static const _kKeywords = 'restricted_keywords_v1';

  static final _domainRe = RegExp(r'^(?!-)([a-z0-9-]{1,63}(?<!-)\.)+[a-z]{2,}$');

  /// Turns "https://www.YouTube.com/watch?v=1" into "youtube.com", or null if invalid.
  static String? normalizeDomain(String input) {
    var s = input.trim().toLowerCase();
    if (s.isEmpty) return null;
    s = s.replaceFirst(RegExp(r'^[a-z]+://'), '');
    s = s.split('/').first.split('?').first.split('#').first.split(':').first;
    if (s.startsWith('www.')) s = s.substring(4);
    return _domainRe.hasMatch(s) ? s : null;
  }

  /// Words that must not appear in a web address or search (kept on this phone only).
  Future<List<String>> loadKeywords() async =>
      (await SharedPreferences.getInstance()).getStringList(_kKeywords) ?? <String>[];

  Future<void> saveKeywords(List<String> v) async =>
      (await SharedPreferences.getInstance()).setStringList(_kKeywords, v);

  /// "  Free Movies " -> "free movies"; null if shorter than 3 letters or too long.
  static String? normalizeKeyword(String input) {
    final s = input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (s.replaceAll(' ', '').length < 3 || s.length > 40) return null;
    return s;
  }

  Future<List<RestrictedApp>> loadApps() async {
    final p = await SharedPreferences.getInstance();
    return _decode(p.getString(_kApps), RestrictedApp.fromJson);
  }

  Future<List<RestrictedSite>> loadSites() async {
    final p = await SharedPreferences.getInstance();
    return _decode(p.getString(_kSites), RestrictedSite.fromJson);
  }

  Future<void> saveApps(List<RestrictedApp> v) async =>
      (await SharedPreferences.getInstance()).setString(_kApps, jsonEncode(v.map((e) => e.toJson()).toList()));

  Future<void> saveSites(List<RestrictedSite> v) async =>
      (await SharedPreferences.getInstance()).setString(_kSites, jsonEncode(v.map((e) => e.toJson()).toList()));

  Future<bool> getAllowOnly() async => (await SharedPreferences.getInstance()).getBool(_kAllowOnly) ?? false;
  Future<void> setAllowOnly(bool v) async => (await SharedPreferences.getInstance()).setBool(_kAllowOnly, v);

  List<T> _decode<T>(String? raw, T Function(Map<String, dynamic>) f) {
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => f(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> queueDelete(String key, int id) async {
    final p = await SharedPreferences.getInstance();
    final l = (p.getStringList(key) ?? []);
    if (!l.contains('$id')) l.add('$id');
    await p.setStringList(key, l);
  }

  Future<void> queueAppDelete(int id) => queueDelete(_kDeleteApps, id);
  Future<void> queueSiteDelete(int id) => queueDelete(_kDeleteSites, id);

  /// Best-effort two-way sync with the Django backend. Never throws: the
  /// device copy is the source of truth for enforcement, so being offline
  /// only delays the upload. Returns true when everything is in sync.
  Future<bool> sync() async {
    final dio = DioClient.instance;
    final p = await SharedPreferences.getInstance();
    try {
      // 1. Push queued deletions.
      for (final entry in {_kDeleteApps: '/api/focus/blocked-apps/', _kDeleteSites: '/api/focus/blocked-websites/'}.entries) {
        final ids = List<String>.from(p.getStringList(entry.key) ?? []);
        for (final id in ids.toList()) {
          try {
            await dio.delete('${entry.value}$id/');
            ids.remove(id);
          } on DioException catch (e) {
            if (e.response?.statusCode == 404) {
              ids.remove(id);
            } else {
              rethrow;
            }
          }
        }
        await p.setStringList(entry.key, ids);
      }

      // 2. Push local items that have no backend id yet.
      var apps = await loadApps();
      for (var i = 0; i < apps.length; i++) {
        if (apps[i].backendId != null) continue;
        try {
          final r = await dio.post('/api/focus/blocked-apps/', data: {
            'app_name': apps[i].label,
            'package_name': apps[i].packageName,
            'is_active': true,
          });
          apps[i] = apps[i].withId((r.data is Map ? r.data['id'] : null) as int?);
        } on DioException catch (e) {
          if (e.response?.statusCode != 400) rethrow; // 400 = already exists server-side
        }
      }
      await saveApps(apps);

      var sites = await loadSites();
      for (var i = 0; i < sites.length; i++) {
        if (sites[i].backendId != null) continue;
        try {
          final r = await dio.post('/api/focus/blocked-websites/', data: {
            'url': 'https://${sites[i].domain}',
            'domain': sites[i].domain,
            'is_active': true,
          });
          sites[i] = sites[i].withId((r.data is Map ? r.data['id'] : null) as int?);
        } on DioException catch (e) {
          if (e.response?.statusCode != 400) rethrow;
        }
      }
      await saveSites(sites);

      // 3. Restore from the account on a fresh install (device list empty).
      if (apps.isEmpty) {
        final r = await dio.get('/api/focus/blocked-apps/');
        final list = _results(r.data);
        apps = [
          for (final j in list)
            if ((j['package_name'] ?? '').toString().isNotEmpty)
              RestrictedApp(
                packageName: j['package_name'].toString(),
                label: (j['app_name'] ?? j['package_name']).toString(),
                backendId: j['id'] as int?,
              )
        ];
        if (apps.isNotEmpty) await saveApps(apps);
      }
      if (sites.isEmpty) {
        final r = await dio.get('/api/focus/blocked-websites/');
        final list = _results(r.data);
        sites = [
          for (final j in list)
            if (normalizeDomain((j['domain'] ?? j['url'] ?? '').toString()) != null)
              RestrictedSite(
                domain: normalizeDomain((j['domain'] ?? j['url']).toString())!,
                backendId: j['id'] as int?,
              )
        ];
        if (sites.isNotEmpty) await saveSites(sites);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> _results(dynamic data) {
    dynamic d = data;
    if (d is Map && d['results'] is List) d = d['results'];
    if (d is Map && d['data'] is List) d = d['data'];
    if (d is Map && d['data'] is Map && d['data']['results'] is List) d = d['data']['results'];
    if (d is! List) return [];
    return d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
