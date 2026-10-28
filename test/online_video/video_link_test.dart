import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/online_video.dart';
import '../../lib/services/online_video/video_link.dart';

ParsedVideoLink ok(String s) {
  final r = VideoLinkParser.parse(s);
  expect(r.ok, isTrue, reason: 'expected "$s" to be a valid link, got ${r.error}');
  return r.link!;
}

void main() {
  group('extractUrl', () {
    test('finds the link inside a share message', () {
      expect(VideoLinkParser.extractUrl('Check this out! https://vm.tiktok.com/ZMabc/ \u{1F64F}'), 'https://vm.tiktok.com/ZMabc/');
    });
    test('drops trailing punctuation', () {
      expect(VideoLinkParser.extractUrl('see (https://youtu.be/dQw4w9WgXcQ).'), 'https://youtu.be/dQw4w9WgXcQ');
    });
    test('accepts a lone link without https://', () {
      expect(VideoLinkParser.extractUrl('youtube.com/watch?v=dQw4w9WgXcQ'), 'youtube.com/watch?v=dQw4w9WgXcQ');
    });
    test('ordinary words and abbreviations are not links', () {
      expect(VideoLinkParser.extractUrl('see e.g. this one'), isNull);
      expect(VideoLinkParser.extractUrl('   '), isNull);
    });
  });

  group('validation', () {
    test('no link', () => expect(VideoLinkParser.parseText('hello there').error, LinkError.noUrl));
    test('non-http scheme', () => expect(VideoLinkParser.parse('ftp://x.com/a').error, LinkError.invalid));
    test('front page of a video site is not a video', () {
      expect(VideoLinkParser.parse('https://www.youtube.com/').error, LinkError.homepageOnly);
      expect(VideoLinkParser.parse('https://www.instagram.com').error, LinkError.homepageOnly);
    });
    test('too long', () => expect(VideoLinkParser.parse('https://a.com/${'x' * 3000}').error, LinkError.invalid));
    test('scheme-less pasted link is accepted', () => expect(ok('youtube.com/watch?v=dQw4w9WgXcQ').platform, VideoPlatform.youtube));
  });

  group('YouTube', () {
    const key = 'youtube:dQw4w9WgXcQ';
    test('every way of sharing one video has the same key', () {
      for (final u in [
        'https://youtu.be/dQw4w9WgXcQ?si=abc',
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=share',
        'https://m.youtube.com/shorts/dQw4w9WgXcQ',
        'https://youtube.com/embed/dQw4w9WgXcQ',
        'https://music.youtube.com/watch?v=dQw4w9WgXcQ&si=x',
      ]) {
        expect(ok(u).key, key, reason: u);
      }
    });
    test('canonical url, embed, thumbnail', () {
      final l = ok('https://youtu.be/dQw4w9WgXcQ?si=abc');
      expect(l.url, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(l.embedUrl, startsWith('https://www.youtube.com/embed/dQw4w9WgXcQ?'));
      expect(l.embedUrl, contains('rel=0'));
      expect(l.directThumbnailUrl, 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg');
      expect(l.oembedUri, isNotNull);
    });
    test('a playlist or channel is kept but has no embed', () {
      final l = ok('https://www.youtube.com/playlist?list=PL1234567890');
      expect(l.platform, VideoPlatform.youtube);
      expect(l.videoId, isNull);
      expect(l.embedUrl, isNull);
    });
  });

  group('Instagram', () {
    test('reel / post forms share a key and drop tracking', () {
      final a = ok('https://www.instagram.com/reel/C1a2B3c4D5e/?igsh=xyz');
      final b = ok('https://www.instagram.com/someuser/reel/C1a2B3c4D5e/');
      expect(a.key, 'instagram:C1a2B3c4D5e');
      expect(b.key, a.key);
      expect(a.url, 'https://www.instagram.com/reel/C1a2B3c4D5e/');
      expect(a.embedUrl, 'https://www.instagram.com/reel/C1a2B3c4D5e/embed/');
      expect(a.oembedUri, isNull); // no public metadata: placeholder
    });
    test('share tokens are not mistaken for shortcodes', () {
      final l = ok('https://www.instagram.com/share/reel/AbCdEfGh/');
      expect(l.videoId, isNull);
      expect(l.embedUrl, isNull);
    });
  });

  group('TikTok', () {
    test('full link', () {
      final l = ok('https://www.tiktok.com/@some.user/video/7234567890123456789?is_from_webapp=1&sender_device=pc');
      expect(l.key, 'tiktok:7234567890123456789');
      expect(l.url, 'https://www.tiktok.com/@some.user/video/7234567890123456789');
      expect(l.embedUrl, 'https://www.tiktok.com/embed/v2/7234567890123456789');
    });
    test('short link is saved, opened outside', () {
      final l = ok('https://vm.tiktok.com/ZMabc123/');
      expect(l.platform, VideoPlatform.tiktok);
      expect(l.embedUrl, isNull);
    });
  });

  group('Facebook / Vimeo / other', () {
    test('facebook watch and reel', () {
      expect(ok('https://www.facebook.com/watch/?v=1234567890&mibextid=x').key, 'facebook:1234567890');
      expect(ok('https://m.facebook.com/SomePage/videos/1234567890/').key, 'facebook:1234567890');
      expect(ok('https://www.facebook.com/reel/9876543210').key, 'facebook:9876543210');
      expect(ok('https://fb.watch/abc123/').videoId, isNull);
    });
    test('vimeo', () {
      final l = ok('https://vimeo.com/123456789');
      expect(l.key, 'vimeo:123456789');
      expect(l.embedUrl, 'https://player.vimeo.com/video/123456789?autoplay=1');
    });
    test('any other link: tracking removed, same page = same key', () {
      final a = ok('https://example.com/a/b/?utm_source=x&id=2');
      final b = ok('https://www.example.com/a/b?id=2&fbclid=zzz');
      expect(a.platform, VideoPlatform.other);
      expect(a.url, 'https://example.com/a/b/?id=2');
      expect(a.key, 'url:example.com/a/b?id=2');
      expect(b.key, a.key);
      expect(a.embedUrl, isNull);
    });
  });
}
