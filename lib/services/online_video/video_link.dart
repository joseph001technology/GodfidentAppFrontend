import '../../models/online_video.dart';

/// Why a piece of text could not be saved as an online video.
enum LinkError {
  /// There was no web address in the text at all.
  noUrl,

  /// There was something, but it is not a usable http(s) address.
  invalid,

  /// A video site's front page or a profile root, not a video.
  homepageOnly,
}

/// A validated link: what is stored, how duplicates are recognised, and the
/// official embed / preview addresses the platform documents for it.
///
/// This is plain Dart with no Flutter or network code, so it can be unit tested.
class ParsedVideoLink {
  /// The cleaned link that is stored, opened and played (tracking parameters removed).
  final String url;

  /// Same video => same key, however the link was shared (youtu.be/ID, watch?v=ID,
  /// shorts/ID, a link with ?si=...). This is what duplicate detection compares.
  final String key;
  final VideoPlatform platform;

  /// The platform's own video id, when it could be read from the link.
  /// null for short links (vm.tiktok.com, fb.watch ...) that need a redirect to resolve.
  final String? videoId;

  /// Extra id part some platforms need (the hash of an unlisted Vimeo video).
  final String? extra;

  const ParsedVideoLink({
    required this.url,
    required this.key,
    required this.platform,
    this.videoId,
    this.extra,
  });

  /// The platform's official embed page, or null when there is none for this link.
  /// A video is only called "playable" in-app when this is non-null; otherwise it
  /// is opened in the platform's app or the browser.
  String? get embedUrl {
    final id = videoId;
    if (id == null) return null;
    switch (platform) {
      case VideoPlatform.youtube:
        // rel=0: only suggest videos from the same channel when it ends. The person
        // chose this one video; nothing plays after it.
        return 'https://www.youtube.com/embed/$id?autoplay=1&rel=0&playsinline=1&modestbranding=1';
      case VideoPlatform.vimeo:
        final h = extra == null ? '' : '&h=$extra';
        return 'https://player.vimeo.com/video/$id?autoplay=1$h';
      case VideoPlatform.instagram:
        // url is https://www.instagram.com/<reel|p|tv>/<code>/
        return '${url}embed/';
      case VideoPlatform.tiktok:
        return 'https://www.tiktok.com/embed/v2/$id';
      case VideoPlatform.facebook:
        // Facebook's official video plugin. Only public videos play.
        return 'https://www.facebook.com/plugins/video.php?href=${Uri.encodeComponent(url)}&show_text=false&autoplay=true';
      case VideoPlatform.other:
        return null;
    }
  }

  /// A preview picture address that needs no request to look up (YouTube only).
  String? get directThumbnailUrl {
    if (platform == VideoPlatform.youtube && videoId != null) {
      return 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    }
    return null;
  }

  /// The platform's public oEmbed endpoint (title + thumbnail), when it offers one
  /// without a login or developer token. Instagram and Facebook do not, so they
  /// have none and show a placeholder.
  Uri? get oembedUri {
    switch (platform) {
      case VideoPlatform.youtube:
        if (videoId == null) return null;
        return Uri.https('www.youtube.com', '/oembed', {'format': 'json', 'url': url});
      case VideoPlatform.tiktok:
        return Uri.https('www.tiktok.com', '/oembed', {'url': url});
      case VideoPlatform.vimeo:
        return Uri.https('vimeo.com', '/api/oembed.json', {'url': url});
      case VideoPlatform.instagram:
      case VideoPlatform.facebook:
      case VideoPlatform.other:
        return null;
    }
  }
}

class LinkParseResult {
  final ParsedVideoLink? link;
  final LinkError? error;
  const LinkParseResult.ok(ParsedVideoLink this.link) : error = null;
  const LinkParseResult.fail(LinkError this.error) : link = null;
  bool get ok => link != null;
}

/// Finds, validates and normalises video links.
class VideoLinkParser {
  VideoLinkParser._();

  static final RegExp _urlRe = RegExp(r'''https?://[^\s<>"'`]+''', caseSensitive: false);
  static final RegExp _bareDomain = RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}(:\d+)?(/\S*)?$', caseSensitive: false);

  // Parameters that only track where a link was shared from. Removing them makes the
  // same video look the same, so duplicates are caught.
  static const _trackingExact = {
    'fbclid', 'gclid', 'igsh', 'igshid', 'si', 'feature', 'mibextid', 'is_from_webapp',
    'sender_device', 'web_id', 'ab_channel', 'pp', 'share_id',
  };

  static bool _isTracking(String k) => k.startsWith('utm_') || _trackingExact.contains(k);

  // ------------------------------------------------------------------ finding

  /// The first web address in shared text ("Look at this! https://...").
  /// A lone address pasted without "https://" is accepted too.
  static String? extractUrl(String text) {
    final m = _urlRe.firstMatch(text);
    if (m != null) return _trimTail(m.group(0)!);
    final t = text.trim();
    if (t.isEmpty) return null;
    if (!RegExp(r'\s').hasMatch(t) && _bareDomain.hasMatch(t)) return t;
    // "watch this youtube.com/watch?v=..." - only trusted for the known video sites.
    for (final tok in t.split(RegExp(r'\s+'))) {
      final c = _trimTail(tok);
      if (_bareDomain.hasMatch(c) && _platformOfHost(_hostOf(c)) != VideoPlatform.other) return c;
    }
    return null;
  }

  static String _trimTail(String s) {
    var out = s;
    while (out.isNotEmpty && '.,;:!?)]}\'"'.contains(out[out.length - 1])) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  static String _hostOf(String bare) {
    final h = bare.split('/').first.split(':').first.toLowerCase();
    return _stripHost(h);
  }

  // ------------------------------------------------------------------ parsing

  /// Shared text -> link: finds the address first, then validates it.
  static LinkParseResult parseText(String text) {
    final u = extractUrl(text);
    if (u == null) return const LinkParseResult.fail(LinkError.noUrl);
    return parse(u);
  }

  static LinkParseResult parse(String raw) {
    try {
      return _parse(raw);
    } catch (_) {
      // Uri can throw on malformed percent-escapes. Never crash on shared text.
      return const LinkParseResult.fail(LinkError.invalid);
    }
  }

  static LinkParseResult _parse(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return const LinkParseResult.fail(LinkError.noUrl);
    if (s.length > 2048) return const LinkParseResult.fail(LinkError.invalid);
    if (!s.contains('://')) {
      if (!_bareDomain.hasMatch(s)) return const LinkParseResult.fail(LinkError.invalid);
      s = 'https://$s';
    }
    final u = Uri.tryParse(s);
    if (u == null || (u.scheme != 'http' && u.scheme != 'https') || u.host.isEmpty || !u.host.contains('.')) {
      return const LinkParseResult.fail(LinkError.invalid);
    }

    final host = _stripHost(u.host.toLowerCase());
    final platform = _platformOfHost(host);
    final segs = u.pathSegments.where((e) => e.isNotEmpty).toList();
    final query = u.queryParameters;

    // A video site's front page is not a video.
    if (platform != VideoPlatform.other && segs.isEmpty && query.isEmpty) {
      return const LinkParseResult.fail(LinkError.homepageOnly);
    }

    switch (platform) {
      case VideoPlatform.youtube:
        return LinkParseResult.ok(_youtube(u, host, segs, query));
      case VideoPlatform.instagram:
        return LinkParseResult.ok(_instagram(u, segs));
      case VideoPlatform.tiktok:
        return LinkParseResult.ok(_tiktok(u, host, segs));
      case VideoPlatform.facebook:
        return LinkParseResult.ok(_facebook(u, host, segs, query));
      case VideoPlatform.vimeo:
        return LinkParseResult.ok(_vimeo(u, segs));
      case VideoPlatform.other:
        return LinkParseResult.ok(_generic(u, host, VideoPlatform.other));
    }
  }

  // ------------------------------------------------------------------ platforms

  static final _ytId = RegExp(r'^[A-Za-z0-9_-]{6,20}$');

  static ParsedVideoLink _youtube(Uri u, String host, List<String> segs, Map<String, String> q) {
    String? id;
    if (host == 'youtu.be') {
      if (segs.isNotEmpty) id = segs.first;
    } else if (segs.isNotEmpty && segs.first == 'watch') {
      id = q['v'];
    } else if (segs.length >= 2 && const {'shorts', 'embed', 'live', 'v'}.contains(segs.first)) {
      id = segs[1];
    }
    if (id != null && _ytId.hasMatch(id)) {
      return ParsedVideoLink(
        url: 'https://www.youtube.com/watch?v=$id',
        key: 'youtube:$id',
        platform: VideoPlatform.youtube,
        videoId: id,
      );
    }
    return _generic(u, host, VideoPlatform.youtube); // playlist, channel...: kept, opened outside
  }

  static ParsedVideoLink _instagram(Uri u, List<String> segs) {
    // /share/... links are tokens that must be resolved by Instagram: not a shortcode.
    if (segs.isNotEmpty && segs.first != 'share') {
      for (var i = 0; i < segs.length - 1; i++) {
        final kind = segs[i];
        if (kind == 'p' || kind == 'reel' || kind == 'reels' || kind == 'tv') {
          final code = segs[i + 1];
          if (RegExp(r'^[A-Za-z0-9_-]{5,}$').hasMatch(code)) {
            final k = kind == 'reels' ? 'reel' : kind;
            return ParsedVideoLink(
              url: 'https://www.instagram.com/$k/$code/',
              key: 'instagram:$code',
              platform: VideoPlatform.instagram,
              videoId: code,
            );
          }
        }
      }
    }
    return _generic(u, 'instagram.com', VideoPlatform.instagram);
  }

  static ParsedVideoLink _tiktok(Uri u, String host, List<String> segs) {
    for (var i = 0; i < segs.length - 1; i++) {
      if (segs[i] == 'video' && RegExp(r'^\d{6,}$').hasMatch(segs[i + 1])) {
        final id = segs[i + 1];
        String? user;
        for (final s in segs) {
          if (s.startsWith('@') && s.length > 1) {
            user = s;
            break;
          }
        }
        final base = _generic(u, host, VideoPlatform.tiktok);
        return ParsedVideoLink(
          url: user == null ? base.url : 'https://www.tiktok.com/$user/video/$id',
          key: 'tiktok:$id',
          platform: VideoPlatform.tiktok,
          videoId: id,
        );
      }
    }
    // vm.tiktok.com/XXXX, tiktok.com/t/XXXX: short links, resolved by TikTok when opened.
    return _generic(u, host, VideoPlatform.tiktok);
  }

  static ParsedVideoLink _facebook(Uri u, String host, List<String> segs, Map<String, String> q) {
    final digits = RegExp(r'^\d{5,}$');
    if (host != 'fb.watch' && segs.isNotEmpty && segs.first != 'share') {
      if (segs.first == 'watch' && q['v'] != null && digits.hasMatch(q['v']!)) {
        final id = q['v']!;
        return ParsedVideoLink(
            url: 'https://www.facebook.com/watch/?v=$id', key: 'facebook:$id', platform: VideoPlatform.facebook, videoId: id);
      }
      if (segs.first == 'reel' && segs.length >= 2 && digits.hasMatch(segs[1])) {
        final id = segs[1];
        return ParsedVideoLink(
            url: 'https://www.facebook.com/reel/$id', key: 'facebook:$id', platform: VideoPlatform.facebook, videoId: id);
      }
      for (var i = 0; i < segs.length - 1; i++) {
        if (segs[i] == 'videos' && digits.hasMatch(segs[i + 1])) {
          final id = segs[i + 1];
          return ParsedVideoLink(
              url: 'https://www.facebook.com/watch/?v=$id', key: 'facebook:$id', platform: VideoPlatform.facebook, videoId: id);
        }
      }
    }
    return _generic(u, host, VideoPlatform.facebook); // fb.watch / share links: resolved by Facebook when opened
  }

  static ParsedVideoLink _vimeo(Uri u, List<String> segs) {
    for (var i = 0; i < segs.length; i++) {
      if (RegExp(r'^\d{5,}$').hasMatch(segs[i])) {
        final id = segs[i];
        String? hash;
        if (i + 1 < segs.length && RegExp(r'^[0-9a-f]{8,}$').hasMatch(segs[i + 1])) hash = segs[i + 1];
        return ParsedVideoLink(
          url: hash == null ? 'https://vimeo.com/$id' : 'https://vimeo.com/$id/$hash',
          key: 'vimeo:$id',
          platform: VideoPlatform.vimeo,
          videoId: id,
          extra: hash,
        );
      }
    }
    return _generic(u, 'vimeo.com', VideoPlatform.vimeo);
  }

  /// Any other address (or a known platform's link we could not read an id from):
  /// tracking parameters removed, host lower-cased, trailing "/" ignored for comparing.
  static ParsedVideoLink _generic(Uri u, String host, VideoPlatform platform) {
    final kept = <String, String>{
      for (final e in u.queryParameters.entries)
        if (!_isTracking(e.key)) e.key: e.value,
    };
    final cleaned = Uri(
      scheme: u.scheme,
      host: u.host.toLowerCase(),
      port: u.hasPort ? u.port : null,
      path: u.path,
      queryParameters: kept.isEmpty ? null : kept,
    ).toString();
    var path = u.path;
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    final keys = kept.keys.toList()..sort();
    final qs = keys.isEmpty ? '' : '?${keys.map((k) => '$k=${kept[k]}').join('&')}';
    return ParsedVideoLink(url: cleaned, key: 'url:$host$path$qs', platform: platform);
  }

  // ------------------------------------------------------------------ hosts

  static String _stripHost(String h) {
    var out = h;
    for (final p in const ['www.', 'm.', 'mobile.', 'web.', 'music.']) {
      if (out.startsWith(p)) out = out.substring(p.length);
    }
    return out;
  }

  static bool _is(String h, String d) => h == d || h.endsWith('.$d');

  static VideoPlatform _platformOfHost(String h) {
    if (h == 'youtu.be' || _is(h, 'youtube.com') || _is(h, 'youtube-nocookie.com')) return VideoPlatform.youtube;
    if (_is(h, 'instagram.com') || h == 'instagr.am') return VideoPlatform.instagram;
    if (_is(h, 'tiktok.com')) return VideoPlatform.tiktok;
    if (_is(h, 'facebook.com') || h == 'fb.watch' || _is(h, 'fb.com')) return VideoPlatform.facebook;
    if (_is(h, 'vimeo.com')) return VideoPlatform.vimeo;
    return VideoPlatform.other;
  }
}
