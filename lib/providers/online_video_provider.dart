import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/online_video.dart';
import '../services/online_video/link_metadata_service.dart';
import '../services/online_video/online_video_gateway.dart';
import '../services/online_video/online_video_store.dart';
import '../services/online_video/thumbnail_cache.dart';

/// The local (on-phone) side of Online Videos. Nothing here uses DioClient or the
/// Godfident server.
final onlineVideoGatewayProvider = Provider<OnlineVideoGateway>((ref) => NativeOnlineVideoGateway.instance);

final onlineVideoStoreProvider = Provider<OnlineVideoStore>(
  (ref) => OnlineVideoStore(ref.watch(onlineVideoGatewayProvider)),
);

final onlineLibraryProvider = StateNotifierProvider<OnlineLibraryController, OnlineLibraryState>(
  (ref) => OnlineLibraryController(
    ref.watch(onlineVideoStoreProvider),
    ref.watch(onlineVideoGatewayProvider),
    LinkMetadataService.instance,
    OnlineThumbnailCache.instance,
  ),
);

class OnlineLibraryState {
  final List<OnlineVideo> items;
  final bool hasMore;

  /// Videos matching the current filter.
  final int total;
  final bool loading;
  final bool loadingMore;
  final String? error;

  /// 'all' | 'none' | 'collection'
  final String scope;
  final String? collectionId;
  final List<OnlineCollection> collections;

  /// Every saved video / the ones not in any collection (for the filter chips).
  final int totalAll;
  final int unsorted;

  /// The phone has internet. Playback and thumbnail downloads need it; browsing the saved list does not.
  final bool online;

  /// Goes up when internet comes back, so cards that failed only because of the network try again.
  final int retryTick;

  const OnlineLibraryState({
    this.items = const [],
    this.hasMore = false,
    this.total = 0,
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.scope = 'all',
    this.collectionId,
    this.collections = const [],
    this.totalAll = 0,
    this.unsorted = 0,
    this.online = true,
    this.retryTick = 0,
  });

  OnlineLibraryState copyWith({
    List<OnlineVideo>? items,
    bool? hasMore,
    int? total,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    String? scope,
    String? collectionId,
    bool clearCollectionId = false,
    List<OnlineCollection>? collections,
    int? totalAll,
    int? unsorted,
    bool? online,
    int? retryTick,
  }) =>
      OnlineLibraryState(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        total: total ?? this.total,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
        scope: scope ?? this.scope,
        collectionId: clearCollectionId ? null : (collectionId ?? this.collectionId),
        collections: collections ?? this.collections,
        totalAll: totalAll ?? this.totalAll,
        unsorted: unsorted ?? this.unsorted,
        online: online ?? this.online,
        retryTick: retryTick ?? this.retryTick,
      );
}

class OnlineLibraryController extends StateNotifier<OnlineLibraryState> {
  OnlineLibraryController(this._store, this._gw, this._meta, this._thumbs) : super(const OnlineLibraryState()) {
    _netSub = _gw.connectivity.listen(_onNet);
  }

  /// Saved records are read this many at a time from the local database.
  static const pageSize = 24;

  final OnlineVideoStore _store;
  final OnlineVideoGateway _gw;
  final LinkMetadataService _meta;
  final OnlineThumbnailCache _thumbs;
  final _uuid = const Uuid();
  StreamSubscription<bool>? _netSub;

  int _gen = 0; // ignores answers to a page request that is no longer wanted
  final Map<String, int> _failures = {};
  final Map<String, DateTime> _retryAt = {};
  final Set<String> _thumbRefreshed = {}; // an expired thumbnail address is refreshed once per session

  @override
  void dispose() {
    _netSub?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------------ loading

  /// First call when the library opens: connectivity, collections, first page.
  Future<void> init() async {
    final online = await _gw.isOnline();
    if (mounted) state = state.copyWith(online: online);
    await reload();
  }

  /// Asks the phone whether it has internet right now (used when the app comes back to the front).
  Future<void> refreshConnectivity() async {
    final on = await _gw.isOnline();
    if (mounted && on != state.online) _onNet(on);
  }

  Future<void> reload() async {
    final gen = ++_gen;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final results = await Future.wait([
        _gw.page(offset: 0, limit: pageSize, scope: state.scope, collectionId: state.collectionId),
        _gw.collections(),
      ]);
      if (!mounted || gen != _gen) return;
      final page = results[0] as VideoPage;
      final cols = results[1] as CollectionList;
      state = state.copyWith(
        items: page.items,
        hasMore: page.hasMore,
        total: page.total,
        loading: false,
        loadingMore: false,
        collections: cols.collections,
        totalAll: cols.total,
        unsorted: cols.unsorted,
      );
    } catch (_) {
      if (!mounted || gen != _gen) return;
      state = state.copyWith(loading: false, error: 'Could not read your saved videos.');
    }
  }

  /// Next page of saved records. Called when the person scrolls near the end of what is shown.
  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final gen = _gen;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _gw.page(
        offset: state.items.length,
        limit: pageSize,
        scope: state.scope,
        collectionId: state.collectionId,
      );
      if (!mounted || gen != _gen) return;
      final have = state.items.map((e) => e.id).toSet();
      state = state.copyWith(
        items: [...state.items, ...page.items.where((e) => !have.contains(e.id))],
        hasMore: page.hasMore,
        total: page.total,
        loadingMore: false,
      );
    } catch (_) {
      if (!mounted || gen != _gen) return;
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> setFilter(String scope, {String? collectionId}) async {
    if (state.scope == scope && state.collectionId == collectionId) return;
    state = state.copyWith(
      scope: scope,
      collectionId: collectionId,
      clearCollectionId: collectionId == null,
      items: const [],
      hasMore: false,
    );
    await reload();
  }

  Future<void> _refreshCollections() async {
    try {
      final cols = await _gw.collections();
      if (!mounted) return;
      state = state.copyWith(collections: cols.collections, totalAll: cols.total, unsorted: cols.unsorted);
    } catch (_) {}
  }

  // ------------------------------------------------------------------ edits

  Future<AddOutcome> addFromText(String text, {String subject = '', String? collectionId}) async {
    final out = await _store.addFromText(text, subject: subject, collectionId: collectionId);
    if (out.kind == AddKind.added) await reload();
    return out;
  }

  Future<void> remove(String id) async {
    await _gw.remove(id);
    if (!mounted) return;
    state = state.copyWith(
      items: [for (final v in state.items) if (v.id != id) v],
      total: math.max(0, state.total - 1),
    );
    await _refreshCollections();
    if (state.hasMore && state.items.length < pageSize) await reload(); // top the page up
  }

  /// Moves a video into a collection (null = take it out of its collection).
  Future<void> move(String id, String? collectionId) async {
    await _gw.setCollection(id, collectionId);
    if (!mounted) return;
    final leavesView = (state.scope == 'collection' && collectionId != state.collectionId) ||
        (state.scope == 'none' && collectionId != null);
    if (leavesView) {
      state = state.copyWith(
        items: [for (final v in state.items) if (v.id != id) v],
        total: math.max(0, state.total - 1),
      );
    } else {
      _replace(id, (v) => collectionId == null ? v.copyWith(clearCollection: true) : v.copyWith(collectionId: collectionId));
    }
    await _refreshCollections();
  }

  Future<void> rename(String id, String title) async {
    await _gw.rename(id, title);
    final fresh = await _gw.get(id);
    if (fresh != null) _replace(id, (_) => fresh);
  }

  Future<OnlineCollection?> createCollection(String name) async {
    final n = name.trim();
    if (n.isEmpty) return null;
    final c = await _gw.createCollection(_uuid.v4(), n);
    await _refreshCollections();
    return c;
  }

  Future<bool> renameCollection(String id, String name) async {
    final ok = await _gw.renameCollection(id, name.trim());
    await _refreshCollections();
    return ok;
  }

  /// The videos stay saved; they just are no longer in that collection.
  Future<void> deleteCollection(String id) async {
    await _gw.deleteCollection(id);
    if (state.scope == 'collection' && state.collectionId == id) {
      await setFilter('all');
    } else {
      await reload();
    }
  }

  void _replace(String id, OnlineVideo Function(OnlineVideo) f) {
    if (!mounted) return;
    state = state.copyWith(items: [for (final v in state.items) v.id == id ? f(v) : v]);
  }

  // ------------------------------------------------------------------ previews (lazy)

  void _onNet(bool online) {
    if (!mounted) return;
    if (online) {
      _failures.clear();
      _retryAt.clear();
      state = state.copyWith(online: true, retryTick: state.retryTick + 1);
    } else {
      state = state.copyWith(online: false);
    }
  }

  /// Asked by a card that is on screen. Looks the video's title / thumbnail up ONCE and
  /// saves the answer locally. Does nothing when:
  ///  - the video was already looked up (or has no public lookup),
  ///  - the phone is offline,
  ///  - an earlier attempt only failed because of the network and it is too soon to retry.
  Future<void> ensureMeta(OnlineVideo v, {bool force = false}) async {
    if (!force && v.metaState != MetaState.pending) return;
    if (!state.online) return;
    final at = _retryAt[v.id];
    if (!force && at != null && DateTime.now().isBefore(at)) return;

    final r = await _meta.fetch(v);
    if (!mounted) return;

    if (r.outcome == MetaOutcome.transient) {
      final n = (_failures[v.id] ?? 0) + 1;
      _failures[v.id] = n;
      // 30 s, 1 min, 2 min ... at most 15 min. Reset when internet comes back.
      _retryAt[v.id] = DateTime.now().add(Duration(seconds: math.min(900, 30 * (1 << math.min(n - 1, 5)))));
      return;
    }
    _failures.remove(v.id);
    _retryAt.remove(v.id);

    final newState = r.outcome == MetaOutcome.found ? MetaState.done : MetaState.unavailable;
    await _gw.saveMeta(v.id, title: r.title, thumbUrl: r.thumbUrl, state: newState);
    final fresh = await _gw.get(v.id);
    if (fresh != null) _replace(v.id, (_) => fresh);
  }

  /// "Refresh preview" in the card menu: forget what was found and ask again.
  Future<void> refreshPreview(OnlineVideo v) async {
    if (v.thumbUrl != null) await _thumbs.evict(v.thumbUrl!);
    _failures.remove(v.id);
    _retryAt.remove(v.id);
    await ensureMeta(v, force: true);
  }

  /// A card's thumbnail address stopped working (expired CDN link). Ask the platform for a fresh
  /// address once per session; if that fails the card keeps its placeholder.
  Future<void> thumbnailGone(OnlineVideo v) async {
    if (!_thumbRefreshed.add(v.id)) return;
    if (v.thumbUrl != null) await _thumbs.evict(v.thumbUrl!);
    await ensureMeta(v, force: true);
  }
}
