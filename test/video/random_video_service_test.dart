import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:godfident/services/video/random_video_service.dart';
import 'package:godfident/services/video/video_selector.dart';

import 'fakes.dart';

void main() {
  group('RandomVideoService', () {
    test('folder not connected -> clear reason, no crash', () async {
      final svc = RandomVideoService(newStore(FakeGateway(FakePhone())));
      final r = await svc.next();
      expect(r.found, isFalse);
      expect(r.reason, NoVideoReason.folderNotConnected);
    });

    test('empty library -> noEligibleVideo (fallback screen case)', () async {
      final (_, _, store) = await connectedWith([]);
      final r = await RandomVideoService(store).next();
      expect(r.reason, NoVideoReason.noEligibleVideo);
    });

    test('plays every video once before any repeats', () async {
      final names = ['a.mp4', 'b.mp4', 'c.mp4', 'd.mp4'];
      final (_, _, store) = await connectedWith(names);
      final svc = RandomVideoService(store, selector: VideoSelector(random: Random(7)));
      final seen = <String>[];
      for (var i = 0; i < names.length; i++) {
        final r = await svc.next();
        seen.add(r.video!.id);
        await svc.confirmPlayed(r.video!.id);
      }
      expect(seen.toSet().length, names.length);
      final fifth = await svc.next();
      expect(fifth.video!.id, isNot(seen.last), reason: 'new cycle must not start with the video just played');
    });

    test('a pick is not counted as played until playback is confirmed', () async {
      final (_, _, store) = await connectedWith(['a.mp4', 'b.mp4']);
      final svc = RandomVideoService(store, selector: VideoSelector(random: Random(1)));
      final first = await svc.next();
      expect(store.byId(first.video!.id)!.lastPlayedAt, isNull);
      expect(store.cycle.played, isEmpty);
      await svc.confirmPlayed(first.video!.id);
      expect(store.byId(first.video!.id)!.lastPlayedAt, isNotNull);
      expect(store.cycle.played, [first.video!.id]);
    });

    test('a video deleted outside Godfident is never picked and nothing crashes', () async {
      final (phone, _, store) = await connectedWith(['a.mp4', 'b.mp4', 'c.mp4']);
      final svc = RandomVideoService(store, selector: VideoSelector(random: Random(2)));
      phone.files.remove('b.mp4');
      for (var i = 0; i < 20; i++) {
        final r = await svc.next();
        expect(r.video!.fileName, isNot('b.mp4'));
        await svc.confirmPlayed(r.video!.id);
      }
    });

    test('an excluded video is never picked', () async {
      final (_, _, store) = await connectedWith(['a.mp4', 'b.mp4']);
      final b = store.videos.firstWhere((v) => v.fileName == 'b.mp4');
      await store.setExcluded(b.id, true);
      final svc = RandomVideoService(store);
      for (var i = 0; i < 10; i++) {
        final r = await svc.next();
        expect(r.video!.fileName, 'a.mp4');
        await svc.confirmPlayed(r.video!.id);
      }
    });

    test('player failures move on to another video and always terminate', () async {
      final (_, _, store) = await connectedWith(['a.mp4', 'b.mp4', 'c.mp4']);
      final svc = RandomVideoService(store, selector: VideoSelector(random: Random(4)));
      final failed = <String>{};
      var attempts = 0;
      while (true) {
        final r = await svc.next(skip: failed);
        if (!r.found) {
          expect(r.reason, NoVideoReason.noEligibleVideo);
          break;
        }
        attempts++;
        expect(attempts, lessThanOrEqualTo(3), reason: 'retry loop must be bounded by the number of videos');
        failed.add(r.video!.id);
        await svc.reportFailure(r.video!.id);
      }
      expect(failed.length, 3);
      expect(store.eligibleVideos, isEmpty);
    });

    test('with one eligible video it simply repeats', () async {
      final (_, _, store) = await connectedWith(['only.mp4']);
      final svc = RandomVideoService(store);
      for (var i = 0; i < 3; i++) {
        final r = await svc.next();
        expect(r.video!.fileName, 'only.mp4');
        await svc.confirmPlayed(r.video!.id);
      }
    });

    test('playback history survives a reinstall', () async {
      final (phone, _, store) = await connectedWith(['a.mp4', 'b.mp4', 'c.mp4']);
      final svc = RandomVideoService(store, selector: VideoSelector(random: Random(8)));
      final r1 = await svc.next();
      await svc.confirmPlayed(r1.video!.id);

      phone.uninstallApp();
      final store2 = newStore(FakeGateway(phone));
      await store2.connectFolder();
      final svc2 = RandomVideoService(store2, selector: VideoSelector(random: Random(9)));
      final r2 = await svc2.next();
      expect(r2.video!.id, isNot(r1.video!.id), reason: 'already-played video must not come straight back after reinstall');
    });
  });
}
