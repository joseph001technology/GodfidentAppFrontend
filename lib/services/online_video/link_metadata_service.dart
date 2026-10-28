import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../models/online_video.dart';
import 'video_link.dart';

enum MetaOutcome {
  /// A title and/or thumbnail address was found.
  found,

  /// The platform offers no preview for this link, or the video is private / removed.
  /// Not retried automatically.
  unavailable,

  /// Only the network failed (offline, timeout, busy server). Worth trying again later.
  transient,
}

class LinkMetadata {
  final MetaOutcome outcome;
  final String? title;
  final String? thumbUrl;
  const LinkMetadata(this.outcome, {this.title, this.thumbUrl});
}

/// Looks up a video's title and thumbnail address from the platform's own PUBLIC
/// oEmbed endpoint (YouTube, TikTok, Vimeo). Instagram and Facebook offer none
/// without a developer token, so they are not asked and show a placeholder.
///
/// Rules (see the task brief):
///  - asked only for a card that is actually on screen, never for the whole library;
///  - one request per video at a time (same video asked twice shares one request);
///  - at most [_maxParallel] requests at once;
///  - the result is saved locally by the caller, so it is not asked again.
///
/// It uses its OWN Dio. It never goes through DioClient, so nothing here can reach
/// the Godfident (Django) server.
class LinkMetadataService {
  LinkMetadataService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              sendTimeout: const Duration(seconds: 8),
              headers: const {'Accept': 'application/json', 'User-Agent': 'Godfident/1.0 (Android)'},
            ));

  static final LinkMetadataService instance = LinkMetadataService();

  static const _maxParallel = 2;

  final Dio _dio;
  final Map<String, Future<LinkMetadata>> _inFlight = {};
  final List<Completer<void>> _waiting = [];
  int _running = 0;

  /// Looks the video up. Safe to call from several cards at once.
  Future<LinkMetadata> fetch(OnlineVideo v) {
    final existing = _inFlight[v.id];
    if (existing != null) return existing;
    final f = _run(v).whenComplete(() => _inFlight.remove(v.id));
    _inFlight[v.id] = f;
    return f;
  }

  Future<void> _acquire() async {
    if (_running < _maxParallel) {
      _running++;
      return;
    }
    final c = Completer<void>();
    _waiting.add(c);
    await c.future; // the slot is handed over by _release (the count stays the same)
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    } else {
      _running--;
    }
  }

  Future<LinkMetadata> _run(OnlineVideo v) async {
    final link = VideoLinkParser.parse(v.url).link;
    final direct = link?.directThumbnailUrl; // YouTube: no request needed for the picture
    final uri = link?.oembedUri;
    if (uri == null) {
      // No public lookup exists for this platform / link.
      return LinkMetadata(MetaOutcome.unavailable, thumbUrl: direct);
    }

    await _acquire();
    try {
      final r = await _dio.getUri<dynamic>(uri, options: Options(validateStatus: (_) => true));
      final code = r.statusCode ?? 0;
      if (code == 200) {
        final data = _asMap(r.data);
        final title = (data?['title'] as String?)?.trim();
        final thumb = direct ?? (data?['thumbnail_url'] as String?);
        if ((title == null || title.isEmpty) && thumb == null) {
          return LinkMetadata(MetaOutcome.unavailable, thumbUrl: direct);
        }
        return LinkMetadata(MetaOutcome.found, title: (title == null || title.isEmpty) ? null : title, thumbUrl: thumb);
      }
      if (code == 429 || code >= 500) return LinkMetadata(MetaOutcome.transient, thumbUrl: direct);
      // 400 / 401 / 403 / 404 / 410: private, removed, or embedding switched off.
      return LinkMetadata(MetaOutcome.unavailable, thumbUrl: direct);
    } on DioException {
      return LinkMetadata(MetaOutcome.transient, thumbUrl: direct);
    } catch (_) {
      return LinkMetadata(MetaOutcome.transient, thumbUrl: direct);
    } finally {
      _release();
    }
  }

  Map<String, dynamic>? _asMap(dynamic d) {
    try {
      if (d is Map) return Map<String, dynamic>.from(d);
      if (d is String) {
        final x = jsonDecode(d);
        if (x is Map) return Map<String, dynamic>.from(x);
      }
    } catch (_) {}
    return null;
  }
}
