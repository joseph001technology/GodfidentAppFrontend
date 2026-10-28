import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/online_video.dart';
import '../../lib/providers/online_video_provider.dart';
import '../../lib/services/online_video/link_metadata_service.dart';
import '../../lib/services/online_video/online_video_store.dart';
import '../../lib/services/online_video/thumbnail_cache.dart';
import 'fake_gateway.dart';

OnlineLibraryController makeController(FakeGateway gw) =>
    OnlineLibraryController(OnlineVideoStore(gw), gw, LinkMetadataService(), OnlineThumbnailCache());

void main() {
  group('OnlineVideoStore (saving links)', () {
    test('saves a shared link, using the share subject as a title hint', () async {
      final gw = FakeGateway();
      final out = await OnlineVideoStore(gw).addFromText(
        'Watch this https://www.instagram.com/reel/C1a2B3c4D5e/?igsh=zz',
        subject: 'Amazing worship moment',
      );
      expect(out.kind, AddKind.added);
      expect(out.video!.platform, VideoPlatform.instagram);
      expect(out.video!.url, 'https://www.instagram.com/reel/C1a2B3c4D5e/');
      expect(out.video!.title, 'Amazing worship moment');
      expect(gw.rows, hasLength(1));
    });

    test('a subject that is only the link again is not used as a title', () async {
      final gw = FakeGateway();
      final out = await OnlineVideoStore(gw).addFromText('https://youtu.be/dQw4w9WgXcQ', subject: 'https://youtu.be/dQw4w9WgXcQ');
      expect(out.video!.title, isNull);
      expect(out.video!.thumbUrl, 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg'); // no request needed
    });

    test('the same video shared in another form is a duplicate', () async {
      final gw = FakeGateway();
      final s = OnlineVideoStore(gw);
      expect((await s.addFromText('https://youtu.be/dQw4w9WgXcQ?si=a')).kind, AddKind.added);
      final again = await s.addFromText('https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=share');
      expect(again.kind, AddKind.duplicate);
      expect(gw.rows, hasLength(1));
    });

    test('text without a usable link saves nothing and explains why', () async {
      final gw = FakeGateway();
      final s = OnlineVideoStore(gw);
      for (final t in ['', 'no link here', 'ftp://x.com/a', 'https://www.youtube.com/']) {
        final o = await s.addFromText(t);
        expect(o.ok, isFalse, reason: t);
        expect(OnlineVideoStore.message(o), isNotEmpty);
      }
      expect(gw.rows, isEmpty);
    });

    test('saving needs no network, thumbnail or title', () async {
      final gw = FakeGateway()..online = false;
      final o = await OnlineVideoStore(gw).addFromText('https://www.facebook.com/reel/9876543210');
      expect(o.kind, AddKind.added);
      expect(o.video!.thumbUrl, isNull);
      expect(o.video!.metaState, MetaState.pending);
    });
  });

  group('OnlineLibraryController (pagination and lazy previews)', () {
    Future<FakeGateway> seeded(int n) async {
      final gw = FakeGateway();
      final s = OnlineVideoStore(gw);
      for (var i = 0; i < n; i++) {
        await s.addFromText('https://www.instagram.com/reel/CODE${i.toString().padLeft(5, '0')}/');
      }
      return gw;
    }

    test('opening reads only the first page, newest first; loadMore reads the next', () async {
      final gw = await seeded(30);
      final c = makeController(gw);
      await c.init();
      expect(c.state.items, hasLength(OnlineLibraryController.pageSize));
      expect(c.state.hasMore, isTrue);
      expect(c.state.total, 30);
      expect(c.state.items.first.url, contains('CODE00029')); // newest first
      expect(gw.pageCalls, 1);

      await c.loadMore();
      expect(c.state.items, hasLength(30));
      expect(c.state.hasMore, isFalse);
      expect(gw.pageCalls, 2);

      await c.loadMore(); // nothing more: no further read
      expect(gw.pageCalls, 2);
      c.dispose();
    });

    test('previews are looked up lazily, once, and never for platforms without a public lookup', () async {
      final gw = await seeded(3);
      final c = makeController(gw);
      await c.init();
      expect(gw.saveMetaCalls, 0); // opening the library asked for nothing

      final v = c.state.items.first;
      await c.ensureMeta(v); // Instagram: no oEmbed -> answered locally, no request
      expect(gw.saveMetaCalls, 1);
      expect(c.state.items.first.metaState, MetaState.unavailable);

      await c.ensureMeta(c.state.items.first); // already answered: asked again? no
      expect(gw.saveMetaCalls, 1);
      c.dispose();
    });

    test('offline: no lookups; when internet returns the retry counter moves', () async {
      final gw = await seeded(1);
      gw.online = false;
      final c = makeController(gw);
      await c.init();
      expect(c.state.online, isFalse);
      await c.ensureMeta(c.state.items.first);
      expect(gw.saveMetaCalls, 0);

      final tick = c.state.retryTick;
      gw.emitOnline(true);
      await Future<void>.delayed(Duration.zero);
      expect(c.state.online, isTrue);
      expect(c.state.retryTick, tick + 1);
      c.dispose();
    });

    test('collections: move, filter, delete keeps the videos', () async {
      final gw = await seeded(4);
      final c = makeController(gw);
      await c.init();
      final col = await c.createCollection('Sermons');
      await c.move(c.state.items[0].id, col!.id);
      await c.move(c.state.items[1].id, col.id);
      expect(c.state.collections.single.count, 2);
      expect(c.state.unsorted, 2);

      await c.setFilter('collection', collectionId: col.id);
      expect(c.state.items, hasLength(2));

      await c.deleteCollection(col.id);
      expect(c.state.scope, 'all');
      expect(c.state.items, hasLength(4)); // nothing was lost
      expect(c.state.collections, isEmpty);
      c.dispose();
    });

    test('removing a saved link removes only that entry', () async {
      final gw = await seeded(3);
      final c = makeController(gw);
      await c.init();
      await c.remove(c.state.items.first.id);
      expect(c.state.items, hasLength(2));
      expect(gw.rows, hasLength(2));
      c.dispose();
    });
  });
}
