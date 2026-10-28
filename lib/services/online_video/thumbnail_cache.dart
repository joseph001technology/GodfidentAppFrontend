import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

enum ThumbFailure {
  /// No failure.
  none,

  /// No internet, timeout or a busy server: try again when the phone is back online.
  network,

  /// The address no longer works (expired CDN link, removed picture): ask the platform for a fresh one.
  gone,

  /// Not an image / too large / cancelled.
  invalid,
}

class ThumbResult {
  final Uint8List? bytes;
  final ThumbFailure failure;
  const ThumbResult.ok(Uint8List this.bytes) : failure = ThumbFailure.none;
  const ThumbResult.fail(this.failure) : bytes = null;
  bool get ok => bytes != null;
}

/// A claim on one thumbnail. Call [release] when the card goes away: if nobody
/// else wants the same picture and it has not finished, the download is cancelled.
class ThumbHandle {
  final Future<ThumbResult> future;
  final void Function() _release;
  bool _released = false;
  ThumbHandle(this.future, this._release);

  void release() {
    if (_released) return;
    _released = true;
    _release();
  }
}

class _Job {
  _Job(this.url, this.allowNetwork);
  final String url;

  /// false = offline: only a picture already on the phone may be used.
  final bool allowNetwork;
  final CancelToken cancel = CancelToken();
  final Completer<ThumbResult> done = Completer<ThumbResult>();
  int refs = 0;
  bool started = false;
}

/// Thumbnails for the Online Videos gallery.
///
///  * bounded: a small in-memory LRU plus a capped folder in the app's CACHE
///    directory (the phone may clear it at any time; nothing in it is precious);
///  * reused: a picture already on the phone is never downloaded again;
///  * lazy: nothing is fetched until a card asks, and a card that scrolls away
///    before its turn cancels the request;
///  * polite: at most [_maxParallel] downloads at once; the same address asked
///    by two cards is downloaded once.
///
/// It uses its OWN Dio and only contacts the platform's picture servers. The
/// Godfident server is never involved.
class OnlineThumbnailCache {
  OnlineThumbnailCache({Dio? dio, Directory? directory})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12),
              headers: const {'User-Agent': 'Godfident/1.0 (Android)', 'Accept': 'image/*'},
            )),
        _dirOverride = directory;

  static final OnlineThumbnailCache instance = OnlineThumbnailCache();

  static const _maxParallel = 3;
  static const _memEntries = 48;
  static const _memBytes = 6 * 1024 * 1024;
  static const _diskFiles = 250;
  static const _diskBytes = 40 * 1024 * 1024;
  static const _maxImageBytes = 3 * 1024 * 1024; // refuse anything bigger than a thumbnail should be

  final Dio _dio;
  final Directory? _dirOverride;

  final LinkedHashMap<String, Uint8List> _mem = LinkedHashMap();
  int _memSize = 0;
  final Map<String, _Job> _jobs = {};
  final List<_Job> _queue = [];
  int _running = 0;
  Directory? _dir;
  bool _dirTried = false;

  // ------------------------------------------------------------------ public

  /// A picture already in memory (instant), or null. Does not start any download.
  Uint8List? peek(String url) {
    final b = _mem.remove(url);
    if (b == null) return null;
    _mem[url] = b; // most recently used goes last
    return b;
  }

  /// Asks for the picture. Look in memory, then on disk, and only then download
  /// (and not even then when [allowNetwork] is false, i.e. the phone is offline).
  ThumbHandle request(String url, {bool allowNetwork = true}) {
    final hit = peek(url);
    if (hit != null) return ThumbHandle(Future.value(ThumbResult.ok(hit)), () {});

    var job = _jobs[url];
    // A download that was cancelled (its card left) must not be handed to a new card.
    if (job != null && job.cancel.isCancelled) job = null;
    if (job == null) {
      job = _Job(url, allowNetwork);
      _jobs[url] = job;
      _queue.add(job);
      scheduleMicrotask(_pump);
    }
    job.refs++;
    final claimed = job;
    return ThumbHandle(claimed.done.future, () => _unref(claimed));
  }

  /// Forgets a picture (used when its address changed or was refreshed).
  Future<void> evict(String url) async {
    final b = _mem.remove(url);
    if (b != null) _memSize -= b.length;
    try {
      final f = await _fileFor(url);
      if (f != null && await f.exists()) await f.delete();
    } catch (_) {}
  }

  // ------------------------------------------------------------------ queue

  void _unref(_Job job) {
    job.refs--;
    if (job.refs > 0 || job.done.isCompleted) return;
    // Nobody wants it any more.
    if (!job.started) {
      _queue.remove(job);
      if (identical(_jobs[job.url], job)) _jobs.remove(job.url);
      job.done.complete(const ThumbResult.fail(ThumbFailure.invalid));
    } else if (!job.cancel.isCancelled) {
      job.cancel.cancel('not needed');
    }
  }

  void _pump() {
    while (_running < _maxParallel && _queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      job.started = true;
      _running++;
      _work(job).whenComplete(() {
        _running--;
        if (identical(_jobs[job.url], job)) _jobs.remove(job.url);
        _pump();
      });
    }
  }

  Future<void> _work(_Job job) async {
    ThumbResult result;
    try {
      final disk = await _readDisk(job.url);
      if (disk != null) {
        _remember(job.url, disk);
        result = ThumbResult.ok(disk);
      } else if (!job.allowNetwork) {
        result = const ThumbResult.fail(ThumbFailure.network); // offline: never contact the platform
      } else {
        result = await _download(job);
      }
    } catch (_) {
      result = const ThumbResult.fail(ThumbFailure.invalid);
    }
    if (!job.done.isCompleted) job.done.complete(result);
  }

  Future<ThumbResult> _download(_Job job) async {
    final uri = Uri.tryParse(job.url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return const ThumbResult.fail(ThumbFailure.invalid);
    }
    try {
      final r = await _dio.get<List<int>>(
        job.url,
        cancelToken: job.cancel,
        options: Options(responseType: ResponseType.bytes, validateStatus: (_) => true),
      );
      final code = r.statusCode ?? 0;
      if (code == 404 || code == 403 || code == 410 || code == 401) return const ThumbResult.fail(ThumbFailure.gone);
      if (code != 200) return const ThumbResult.fail(ThumbFailure.network);
      final data = r.data;
      if (data == null || data.isEmpty || data.length > _maxImageBytes) {
        return const ThumbResult.fail(ThumbFailure.invalid);
      }
      final type = r.headers.value('content-type') ?? '';
      if (type.isNotEmpty && !type.startsWith('image/')) return const ThumbResult.fail(ThumbFailure.invalid);
      final bytes = Uint8List.fromList(data);
      _remember(job.url, bytes);
      unawaited(_writeDisk(job.url, bytes));
      return ThumbResult.ok(bytes);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return const ThumbResult.fail(ThumbFailure.invalid);
      return const ThumbResult.fail(ThumbFailure.network);
    } catch (_) {
      return const ThumbResult.fail(ThumbFailure.network);
    }
  }

  // ------------------------------------------------------------------ memory

  void _remember(String url, Uint8List bytes) {
    final old = _mem.remove(url);
    if (old != null) _memSize -= old.length;
    _mem[url] = bytes;
    _memSize += bytes.length;
    while ((_mem.length > _memEntries || _memSize > _memBytes) && _mem.length > 1) {
      final k = _mem.keys.first;
      _memSize -= _mem.remove(k)!.length;
    }
  }

  // ------------------------------------------------------------------ disk

  Future<Directory?> _directory() async {
    if (_dirTried) return _dir;
    _dirTried = true;
    try {
      // On Android Directory.systemTemp is the app's cache folder: bounded by us,
      // and cleared by Android when space is needed. That is what "not permanent" means here.
      final d = _dirOverride ?? Directory('${Directory.systemTemp.path}/godfident_online_thumbs');
      if (!await d.exists()) await d.create(recursive: true);
      _dir = d;
    } catch (_) {
      _dir = null; // memory-only is fine
    }
    return _dir;
  }

  Future<File?> _fileFor(String url) async {
    final d = await _directory();
    if (d == null) return null;
    final name = sha1.convert(url.codeUnits).toString();
    return File('${d.path}/$name.img');
  }

  Future<Uint8List?> _readDisk(String url) async {
    try {
      final f = await _fileFor(url);
      if (f == null || !await f.exists()) return null;
      final bytes = await f.readAsBytes();
      if (bytes.isEmpty) return null;
      unawaited(f.setLastModified(DateTime.now()).catchError((_) {})); // marks it recently used
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(String url, Uint8List bytes) async {
    try {
      final f = await _fileFor(url);
      if (f == null) return;
      await f.writeAsBytes(bytes, flush: false);
      await _prune();
    } catch (_) {}
  }

  /// Keeps the folder under [_diskFiles] files and [_diskBytes] bytes, oldest first.
  Future<void> _prune() async {
    final d = await _directory();
    if (d == null) return;
    try {
      final files = <(File, int, DateTime)>[];
      var total = 0;
      await for (final e in d.list()) {
        if (e is! File) continue;
        final st = await e.stat();
        files.add((e, st.size, st.modified));
        total += st.size;
      }
      if (files.length <= _diskFiles && total <= _diskBytes) return;
      files.sort((a, b) => a.$3.compareTo(b.$3));
      var count = files.length;
      for (final f in files) {
        if (count <= _diskFiles && total <= _diskBytes) break;
        try {
          await f.$1.delete();
          count--;
          total -= f.$2;
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) debugPrint('thumbnail prune failed: $e');
    }
  }
}
