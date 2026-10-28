import 'dart:async';

import '../../lib/models/online_video.dart';
import '../../lib/services/online_video/online_video_gateway.dart';

/// In-memory stand-in for the Android database, for tests. It mimics the contract of
/// OnlineVideoPlugin.kt: newest first, LIMIT/OFFSET paging, UNIQUE key, collections.
class FakeGateway implements OnlineVideoGateway {
  final List<OnlineVideo> rows = [];
  final Map<String, String> keys = {}; // key -> id
  final List<OnlineCollection> cols = [];
  final List<SharedContent> pending = [];
  bool online = true;
  int pageCalls = 0;
  int saveMetaCalls = 0;
  int _clock = 0;
  final _net = StreamController<bool>.broadcast();
  final _pokes = StreamController<void>.broadcast();

  void emitOnline(bool v) {
    online = v;
    _net.add(v);
  }

  List<OnlineVideo> _filtered(String scope, String? cid) {
    final l = rows.where((v) {
      if (scope == 'collection') return v.collectionId == cid;
      if (scope == 'none') return v.collectionId == null;
      return true;
    }).toList();
    l.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return l;
  }

  @override
  Future<VideoPage> page({required int offset, required int limit, String scope = 'all', String? collectionId}) async {
    pageCalls++;
    final l = _filtered(scope, collectionId);
    final slice = l.skip(offset).take(limit).toList();
    return VideoPage(items: slice, hasMore: offset + slice.length < l.length, total: l.length);
  }

  @override
  Future<AddResult> add({
    required String id,
    required String url,
    required String key,
    required VideoPlatform platform,
    String? title,
    String? thumbUrl,
    String? collectionId,
  }) async {
    final existing = keys[key];
    if (existing != null) return AddResult(AddStatus.duplicate, rows.firstWhere((v) => v.id == existing));
    final v = OnlineVideo(
      id: id,
      url: url,
      platform: platform,
      title: title,
      thumbUrl: thumbUrl,
      collectionId: collectionId,
      addedAt: DateTime.fromMillisecondsSinceEpoch(++_clock),
    );
    rows.add(v);
    keys[key] = id;
    return AddResult(AddStatus.added, v);
  }

  void _put(String id, OnlineVideo Function(OnlineVideo) f) {
    final i = rows.indexWhere((v) => v.id == id);
    if (i >= 0) rows[i] = f(rows[i]);
  }

  @override
  Future<OnlineVideo?> get(String id) async {
    for (final v in rows) {
      if (v.id == id) return v;
    }
    return null;
  }

  @override
  Future<void> remove(String id) async {
    rows.removeWhere((v) => v.id == id);
    keys.removeWhere((_, v) => v == id);
  }

  @override
  Future<void> setCollection(String id, String? collectionId) async =>
      _put(id, (v) => collectionId == null ? v.copyWith(clearCollection: true) : v.copyWith(collectionId: collectionId));

  @override
  Future<void> rename(String id, String title) async =>
      _put(id, (v) => v.copyWith(title: title.trim(), titleEdited: title.trim().isNotEmpty));

  @override
  Future<void> saveMeta(String id, {String? title, String? thumbUrl, required int state}) async {
    saveMetaCalls++;
    _put(id, (v) => v.copyWith(
          title: (title != null && !v.titleEdited) ? title : null,
          thumbUrl: thumbUrl,
          metaState: state,
        ));
  }

  @override
  Future<CollectionList> collections() async => CollectionList(
        collections: [for (final c in cols) OnlineCollection(id: c.id, name: c.name, count: rows.where((v) => v.collectionId == c.id).length)],
        total: rows.length,
        unsorted: rows.where((v) => v.collectionId == null).length,
      );

  @override
  Future<OnlineCollection?> createCollection(String id, String name) async {
    for (final c in cols) {
      if (c.name.toLowerCase() == name.toLowerCase()) return c;
    }
    final c = OnlineCollection(id: id, name: name);
    cols.add(c);
    return c;
  }

  @override
  Future<bool> renameCollection(String id, String name) async => true;

  @override
  Future<void> deleteCollection(String id) async {
    cols.removeWhere((c) => c.id == id);
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].collectionId == id) rows[i] = rows[i].copyWith(clearCollection: true);
    }
  }

  @override
  Future<SharedContent?> takePendingShare() async => pending.isEmpty ? null : pending.removeAt(0);

  @override
  Stream<void> get sharePokes => _pokes.stream;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get connectivity => _net.stream;

  @override
  Future<bool> openExternal(String url) async => true;

  @override
  Future<bool> play({required String embedUrl, required String originalUrl, required String title, required String platform}) async => true;
}
