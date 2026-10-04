import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/focus_blocking_service.dart';
import '../services/restriction_store.dart';
import '../services/website_protection_service.dart';

// ── Installed apps (read from the device) ─────────────────────────
final installedAppsProvider = FutureProvider.autoDispose<List<InstalledApp>>((ref) {
  return FocusBlockingService.instance.getInstalledApps();
});

// ── Restricted apps (device-stored, synced when online) ───────────
final restrictedAppsProvider =
    StateNotifierProvider<RestrictedAppsNotifier, AsyncValue<List<RestrictedApp>>>((ref) => RestrictedAppsNotifier());

class RestrictedAppsNotifier extends StateNotifier<AsyncValue<List<RestrictedApp>>> {
  RestrictedAppsNotifier() : super(const AsyncValue.loading()) {
    load();
  }
  final _store = RestrictionStore.instance;

  Future<void> load() async {
    state = AsyncValue.data(await _store.loadApps());
    // Pull/push in the background; refresh the list if it changed.
    if (await _store.sync()) state = AsyncValue.data(await _store.loadApps());
  }

  Future<void> setSelection(List<InstalledApp> selected) async {
    final current = await _store.loadApps();
    final next = <RestrictedApp>[];
    for (final a in selected) {
      final existing = current.where((c) => c.packageName == a.packageName);
      next.add(existing.isNotEmpty ? existing.first : RestrictedApp(packageName: a.packageName, label: a.label));
    }
    for (final c in current) {
      if (!selected.any((s) => s.packageName == c.packageName) && c.backendId != null) {
        await _store.queueAppDelete(c.backendId!);
      }
    }
    await _store.saveApps(next);
    state = AsyncValue.data(next);
    if (await _store.sync()) state = AsyncValue.data(await _store.loadApps());
  }

  Future<void> remove(String packageName) async {
    final current = await _store.loadApps();
    final gone = current.where((c) => c.packageName == packageName).toList();
    for (final g in gone) {
      if (g.backendId != null) await _store.queueAppDelete(g.backendId!);
    }
    final next = current.where((c) => c.packageName != packageName).toList();
    await _store.saveApps(next);
    state = AsyncValue.data(next);
    _store.sync();
  }
}

// ── Restricted websites ───────────────────────────────────────────
final restrictedSitesProvider =
    StateNotifierProvider<RestrictedSitesNotifier, AsyncValue<List<RestrictedSite>>>((ref) => RestrictedSitesNotifier());

class RestrictedSitesNotifier extends StateNotifier<AsyncValue<List<RestrictedSite>>> {
  RestrictedSitesNotifier() : super(const AsyncValue.loading()) {
    load();
  }
  final _store = RestrictionStore.instance;
  final _web = WebsiteProtectionService.instance;

  Future<void> load() async {
    state = AsyncValue.data(await _store.loadSites());
    if (await _store.sync()) state = AsyncValue.data(await _store.loadSites());
    await _push();
  }

  /// Hand the list to the Android filter. Website protection is ALWAYS ON
  /// while at least one site is listed (and off when the list is empty).
  Future<void> _push() async {
    final sites = state.valueOrNull ?? [];
    await _web.ensureRunning(sites.map((s) => s.domain).toList());
  }

  /// Cheap re-check used on app resume: restarts protection if it stopped.
  Future<void> guard() => _push();

  /// Returns null on success, or a user-facing error message.
  Future<String?> add(String input) async {
    final d = RestrictionStore.normalizeDomain(input);
    if (d == null) return 'That is not a valid website. Try something like youtube.com';
    final current = await _store.loadSites();
    if (current.any((s) => s.domain == d)) return '$d is already protected.';
    final next = [...current, RestrictedSite(domain: d)];
    await _store.saveSites(next);
    state = AsyncValue.data(next);
    await _push();
    _store.sync().then((_) async => state = AsyncValue.data(await _store.loadSites()));
    return null;
  }

  Future<void> remove(String domain) async {
    final current = await _store.loadSites();
    for (final g in current.where((c) => c.domain == domain)) {
      if (g.backendId != null) await _store.queueSiteDelete(g.backendId!);
    }
    final next = current.where((c) => c.domain != domain).toList();
    await _store.saveSites(next);
    state = AsyncValue.data(next);
    await _push();
    _store.sync();
  }
}

final websiteStatusProvider = FutureProvider.autoDispose<WebsiteProtectionStatus>((ref) {
  return WebsiteProtectionService.instance.status();
});

final usageAccessProvider = FutureProvider.autoDispose<bool>((ref) {
  return FocusBlockingService.instance.hasUsageAccess();
});

final focusSessionInfoProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return FocusBlockingService.instance.getSessionInfo();
});
