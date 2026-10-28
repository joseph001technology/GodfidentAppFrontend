import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/online_video.dart';

/// What the phone's share menu handed to Godfident.
class SharedContent {
  /// Shared text (usually "<message> <link>"). May be empty.
  final String text;

  /// The sender's subject / title hint, when it gave one.
  final String subject;
  const SharedContent({this.text = '', this.subject = ''});
}

enum AddStatus { added, duplicate, failed }

class AddResult {
  final AddStatus status;
  final OnlineVideo? video;
  const AddResult(this.status, [this.video]);
}

/// Everything the Online Videos feature needs from the phone.
///
/// The saved links live in a local SQLite database owned by the Android side
/// (OnlineVideoPlugin.kt). Nothing here ever talks to the Godfident server.
abstract class OnlineVideoGateway {
  /// One page of saved videos, newest first.
  /// [scope]: 'all' | 'none' (not in a collection) | 'collection' (uses [collectionId]).
  Future<VideoPage> page({required int offset, required int limit, String scope = 'all', String? collectionId});

  Future<AddResult> add({
    required String id,
    required String url,
    required String key,
    required VideoPlatform platform,
    String? title,
    String? thumbUrl,
    String? collectionId,
  });

  Future<OnlineVideo?> get(String id);
  Future<void> remove(String id);
  Future<void> setCollection(String id, String? collectionId);

  /// The person's own title. An empty title goes back to the platform's / default one.
  Future<void> rename(String id, String title);

  /// Saves what the one-time lookup found. A title never replaces one the person typed.
  Future<void> saveMeta(String id, {String? title, String? thumbUrl, required int state});

  Future<CollectionList> collections();
  Future<OnlineCollection?> createCollection(String id, String name);
  Future<bool> renameCollection(String id, String name);
  Future<void> deleteCollection(String id);

  /// Text received from the Android share menu since the last call (null = nothing).
  Future<SharedContent?> takePendingShare();

  /// Fires when new shared text may be waiting. Call [takePendingShare] to read it.
  Stream<void> get sharePokes;

  Future<bool> isOnline();

  /// Fires with the new state whenever the phone gains or loses internet.
  Stream<bool> get connectivity;

  /// Opens the link in the platform's own app or the browser.
  Future<bool> openExternal(String url);

  /// Opens the in-app viewer (an official embed page). Returns false if it could not open.
  Future<bool> play({required String embedUrl, required String originalUrl, required String title, required String platform});
}

class CollectionList {
  final List<OnlineCollection> collections;
  final int total;
  final int unsorted;
  const CollectionList({this.collections = const [], this.total = 0, this.unsorted = 0});
}

/// The real thing: talks to OnlineVideoPlugin.kt over a method channel.
class NativeOnlineVideoGateway implements OnlineVideoGateway {
  NativeOnlineVideoGateway._() {
    _ch.setMethodCallHandler(_fromNative);
  }

  /// One instance only: a method channel can have just one handler.
  static final NativeOnlineVideoGateway instance = NativeOnlineVideoGateway._();

  static const _ch = MethodChannel('com.godfident/online_videos');

  final _pokes = StreamController<void>.broadcast();
  final _net = StreamController<bool>.broadcast();

  @override
  Stream<void> get sharePokes => _pokes.stream;

  @override
  Stream<bool> get connectivity => _net.stream;

  Future<dynamic> _fromNative(MethodCall call) async {
    switch (call.method) {
      case 'shared':
        _pokes.add(null);
      case 'connectivity':
        _net.add(call.arguments == true);
    }
    return null;
  }

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } catch (e) {
      if (kDebugMode) debugPrint('online_videos.$method failed: $e');
      return null;
    }
  }

  @override
  Future<VideoPage> page({required int offset, required int limit, String scope = 'all', String? collectionId}) async {
    final m = await _call<Map<dynamic, dynamic>>('page', {
      'offset': offset,
      'limit': limit,
      'scope': scope,
      'collectionId': collectionId,
    });
    if (m == null) throw StateError('Could not read the saved videos.');
    final items = [for (final r in (m['items'] as List? ?? const [])) OnlineVideo.fromMap(r as Map)];
    return VideoPage(items: items, hasMore: m['hasMore'] == true, total: (m['total'] as num?)?.toInt() ?? items.length);
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
    final m = await _call<Map<dynamic, dynamic>>('add', {
      'id': id,
      'url': url,
      'key': key,
      'platform': platform.id,
      'title': title,
      'thumbUrl': thumbUrl,
      'collectionId': collectionId,
    });
    if (m == null || m['video'] == null) return const AddResult(AddStatus.failed);
    final v = OnlineVideo.fromMap(m['video'] as Map);
    return AddResult(m['status'] == 'duplicate' ? AddStatus.duplicate : AddStatus.added, v);
  }

  @override
  Future<OnlineVideo?> get(String id) async {
    final m = await _call<Map<dynamic, dynamic>>('get', {'id': id});
    return m == null ? null : OnlineVideo.fromMap(m);
  }

  @override
  Future<void> remove(String id) async {
    await _call<bool>('remove', {'id': id});
  }

  @override
  Future<void> setCollection(String id, String? collectionId) async {
    await _call<bool>('setCollection', {'id': id, 'collectionId': collectionId});
  }

  @override
  Future<void> rename(String id, String title) async {
    await _call<bool>('rename', {'id': id, 'title': title});
  }

  @override
  Future<void> saveMeta(String id, {String? title, String? thumbUrl, required int state}) async {
    await _call<bool>('saveMeta', {'id': id, 'title': title, 'thumbUrl': thumbUrl, 'state': state});
  }

  @override
  Future<CollectionList> collections() async {
    final m = await _call<Map<dynamic, dynamic>>('collections');
    if (m == null) return const CollectionList();
    return CollectionList(
      collections: [for (final c in (m['collections'] as List? ?? const [])) OnlineCollection.fromMap(c as Map)],
      total: (m['total'] as num?)?.toInt() ?? 0,
      unsorted: (m['unsorted'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<OnlineCollection?> createCollection(String id, String name) async {
    final m = await _call<Map<dynamic, dynamic>>('createCollection', {'id': id, 'name': name});
    return m == null ? null : OnlineCollection.fromMap(m);
  }

  @override
  Future<bool> renameCollection(String id, String name) async =>
      await _call<bool>('renameCollection', {'id': id, 'name': name}) ?? false;

  @override
  Future<void> deleteCollection(String id) async {
    await _call<bool>('deleteCollection', {'id': id});
  }

  @override
  Future<SharedContent?> takePendingShare() async {
    final m = await _call<Map<dynamic, dynamic>>('takePendingShare');
    if (m == null) return null;
    return SharedContent(text: (m['text'] as String?) ?? '', subject: (m['subject'] as String?) ?? '');
  }

  @override
  Future<bool> isOnline() async => await _call<bool>('isOnline') ?? true;

  @override
  Future<bool> openExternal(String url) async => await _call<bool>('openExternal', {'url': url}) ?? false;

  @override
  Future<bool> play({
    required String embedUrl,
    required String originalUrl,
    required String title,
    required String platform,
  }) async =>
      await _call<bool>('play', {
        'embedUrl': embedUrl,
        'originalUrl': originalUrl,
        'title': title,
        'platform': platform,
      }) ??
      false;
}
