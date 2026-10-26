import 'package:flutter_test/flutter_test.dart';
import 'package:godfident/models/local_video.dart';
import 'package:godfident/services/video/video_folder_gateway.dart';
import 'package:godfident/services/video/video_library_store.dart';

import 'fakes.dart';

void main() {
  group('first run', () {
    test('not connected until the folder is picked; nothing crashes', () async {
      final gw = FakeGateway(FakePhone());
      final store = newStore(gw);
      final s = await store.load();
      expect(s.folder.connected, isFalse);
      expect(s.folder.problem, FolderProblem.notConnected);
      expect(s.videos, isEmpty);
    });

    test('connecting creates the folder once and writes a manifest', () async {
      final (phone, _, store) = await connectedWith([]);
      expect(phone.foldersCreated, 1);
      expect(VideoManifest.tryParse(phone.manifestMain), isNotNull);
      expect(store.libraryId, isNotEmpty);
    });
  });

  group('survives uninstall / reinstall / another account', () {
    test('reinstall reuses the same folder and keeps ids, titles, exclusions and history', () async {
      final (phone, _, store) = await connectedWith(['grace.mp4', 'psalm23.mp4']);
      final before = store.videos;
      expect(before.length, 2);
      final grace = before.firstWhere((v) => v.fileName == 'grace.mp4');
      await store.rename(grace.id, 'Amazing Grace');
      await store.setExcluded(before.firstWhere((v) => v.fileName == 'psalm23.mp4').id, true);
      await store.recordPlayback(grace.id, CycleState(order: [grace.id], played: [grace.id], previousId: grace.id));
      final libraryId = store.libraryId;

      // Uninstall: Android drops the permission, the folder and files stay.
      phone.uninstallApp();

      // Reinstall (or log in with a different account: nothing here depends on the account).
      final store2 = newStore(FakeGateway(phone));
      final cold = await store2.load();
      expect(cold.folder.connected, isFalse, reason: 'permission is gone until the user reconnects');

      final out = await store2.connectFolder();
      expect(out.pick.ok, isTrue);
      expect(phone.foldersCreated, 1, reason: 'the existing folder must be reused, never a second one');
      expect(out.state!.manifestRecovered, isTrue);
      expect(out.state!.manifestRebuilt, isFalse);
      expect(store2.libraryId, libraryId);

      final after = store2.videos;
      expect(after.map((v) => v.id).toSet(), before.map((v) => v.id).toSet());
      expect(store2.byId(grace.id)!.title, 'Amazing Grace');
      expect(store2.byId(grace.id)!.lastPlayedAt, isNotNull);
      expect(store2.byId(before.firstWhere((v) => v.fileName == 'psalm23.mp4').id)!.excluded, isTrue);
      expect(store2.cycle.previousId, grace.id);
    });

    test('folder deleted outside Godfident is reported, then reconnecting recreates it only once', () async {
      final (phone, _, _) = await connectedWith([]);
      phone.folderExists = false;
      final store = newStore(FakeGateway(phone));
      final s = await store.load();
      expect(s.folder.problem, FolderProblem.folderMissing);
      await store.connectFolder();
      expect(phone.foldersCreated, 2);
      expect((await store.load()).folder.connected, isTrue);
    });
  });

  group('manifest recovery', () {
    test('videos but no manifest: library rebuilt from files, nothing lost, ids unique', () async {
      final phone = FakePhone()
        ..granted = true
        ..folderExists = true
        ..foldersCreated = 1;
      phone.addVideo('one.mp4');
      phone.addVideo('two.mkv');
      phone.addVideo('three.webm');
      final s = await newStore(FakeGateway(phone)).load();
      expect(s.manifestRebuilt, isTrue);
      expect(s.videos.length, 3);
      expect(s.videos.map((v) => v.id).toSet().length, 3);
      expect(s.videos.every((v) => v.source == VideoSource.discovered), isTrue);
      expect(s.eligibleCount, 3);
      expect(phone.manifestMain, isNotNull, reason: 'the rebuilt manifest is written back');
    });

    test('corrupt manifest: rebuilt safely, no crash', () async {
      final (phone, _, _) = await connectedWith(['a.mp4']);
      phone.manifestMain = '{ not json';
      phone.uninstallApp();
      final store = newStore(FakeGateway(phone));
      final out = await store.connectFolder();
      expect(out.state!.manifestRebuilt, isTrue);
      expect(out.state!.videos.length, 1);
      expect(VideoManifest.tryParse(phone.manifestMain), isNotNull);
    });

    test('interrupted save: the temp copy is used when the main file is unreadable', () async {
      final (phone, _, store) = await connectedWith(['a.mp4', 'b.mp4']);
      final ids = store.videos.map((v) => v.id).toSet();
      phone.manifestTmp = phone.manifestMain;
      phone.manifestMain = '';
      phone.uninstallApp();
      final s2 = newStore(FakeGateway(phone));
      await s2.connectFolder();
      expect(s2.videos.map((v) => v.id).toSet(), ids);
    });

    test('a bad record inside an otherwise valid manifest is skipped', () {
      final m = VideoManifest.tryParse('{"version":1,"libraryId":"L","videos":[{"x":1},{"id":"v1","fileName":"a.mp4"}]}');
      expect(m, isNotNull);
      expect(m!.videos.map((v) => v.id), ['v1']);
    });

    test('the manifest never stores uris or availability', () async {
      final (phone, _, _) = await connectedWith(['a.mp4']);
      expect(phone.manifestMain, isNot(contains('fake://')));
      expect(phone.manifestMain, isNot(contains('content://')));
      expect(phone.manifestMain, isNot(contains('available')));
    });
  });

  group('deleted / moved / renamed files', () {
    test('a file deleted with the file manager is excluded without crashing, and returns with the same id', () async {
      final (phone, gw, store) = await connectedWith(['a.mp4', 'b.mp4']);
      final a = store.videos.firstWhere((v) => v.fileName == 'a.mp4');
      final saved = phone.files.remove('a.mp4')!;

      final s = await store.load();
      expect(s.eligibleCount, 1);
      expect(store.byId(a.id)!.available, isFalse);
      expect(store.eligibleVideos.map((v) => v.id), isNot(contains(a.id)));

      phone.files['a.mp4'] = saved; // restored
      await store.load();
      expect(store.byId(a.id)!.available, isTrue);
      expect(gw.failList, isFalse);
    });

    test('a file renamed outside Godfident keeps its id', () async {
      final (phone, _, store) = await connectedWith(['old.mp4', 'other.mp4']);
      final old = store.videos.firstWhere((v) => v.fileName == 'old.mp4');
      phone.files['new.mp4'] = phone.files.remove('old.mp4')!;
      await store.load();
      expect(store.byId(old.id)!.fileName, 'new.mp4');
      expect(store.byId(old.id)!.available, isTrue);
      expect(store.videos.length, 2);
    });

    test('an ambiguous rename (two identical-size files) is not guessed', () async {
      final phone = FakePhone();
      phone.addVideo('x.mp4', size: 5000);
      phone.addVideo('y.mp4', size: 5000);
      final gw = FakeGateway(phone);
      final store = newStore(gw);
      await store.connectFolder();
      final oldIds = store.videos.map((v) => v.id).toSet();
      phone.files['p.mp4'] = phone.files.remove('x.mp4')!;
      phone.files['q.mp4'] = phone.files.remove('y.mp4')!;
      await store.load();
      final eligible = store.eligibleVideos;
      expect(eligible.length, 2);
      expect(eligible.map((v) => v.id).toSet().intersection(oldIds), isEmpty, reason: 'new ids, not a wrong match');
      expect(store.videos.where((v) => !v.available).length, 2);
    });

    test('an unreachable folder marks everything unavailable instead of crashing', () async {
      final (_, gw, store) = await connectedWith(['a.mp4']);
      gw.failList = true;
      final s = await store.load();
      expect(s.eligibleCount, 0);
      expect(s.videos.length, 1);
      gw.failList = false;
      expect((await store.load()).eligibleCount, 1);
    });
  });

  group('library entries vs files', () {
    test('removing from the library keeps the file, and a refresh does not re-add it', () async {
      final (phone, _, store) = await connectedWith(['a.mp4']);
      final a = store.videos.single;
      await store.removeFromLibrary(a.id);
      expect(phone.files.containsKey('a.mp4'), isTrue);
      await store.load();
      expect(store.videos, isEmpty);
      expect(store.eligibleVideos, isEmpty);
    });

    test('importing the same file again brings a removed entry back (same id)', () async {
      final (phone, _, store) = await connectedWith(['a.mp4']);
      final a = store.videos.single;
      await store.removeFromLibrary(a.id);
      phone.external['content://pick/1'] = ExternalFile('a.mp4', phone.files['a.mp4']!);
      final out = await store.importVideo('content://pick/1');
      expect(out.ok, isTrue);
      expect(out.duplicate, isTrue);
      expect(out.video!.id, a.id);
      expect(store.videos.length, 1);
    });

    test('explicit file deletion deletes the file; a refusal keeps the entry', () async {
      final (phone, gw, store) = await connectedWith(['a.mp4', 'b.mp4']);
      final a = store.videos.firstWhere((v) => v.fileName == 'a.mp4');
      final b = store.videos.firstWhere((v) => v.fileName == 'b.mp4');

      gw.failDelete = true;
      expect(await store.deleteFilePermanently(a.id), isFalse);
      expect(phone.files.containsKey('a.mp4'), isTrue);
      expect(store.byId(a.id), isNotNull);

      gw.failDelete = false;
      expect(await store.deleteFilePermanently(b.id), isTrue);
      expect(phone.files.containsKey('b.mp4'), isFalse);
      expect(store.byId(b.id), isNull);
    });
  });

  group('import', () {
    test('a good video is copied into the folder, registered once with a permanent id', () async {
      final (phone, _, store) = await connectedWith([]);
      phone.external['content://pick/1'] = ExternalFile('sermon.mp4', FakeFile(size: 123456, durationMs: 90000));
      final out = await store.importVideo('content://pick/1', source: VideoSource.imported);
      expect(out.ok, isTrue);
      expect(phone.files.containsKey('sermon.mp4'), isTrue);
      expect(out.video!.id, isNotEmpty);
      expect(out.video!.durationMs, 90000);
      expect(out.video!.title, 'sermon');
      expect(store.videos.length, 1);

      // Importing it a second time does not create a second entry or a second copy.
      final again = await store.importVideo('content://pick/1');
      expect(again.duplicate, isTrue);
      expect(again.video!.id, out.video!.id);
      expect(store.videos.length, 1);
      expect(phone.files.length, 1);
    });

    test('an unsupported file is not registered and its fresh copy is removed', () async {
      final (phone, _, store) = await connectedWith([]);
      phone.external['content://pick/2'] = ExternalFile('bad.mp4', FakeFile(size: 999, playable: false));
      final out = await store.importVideo('content://pick/2');
      expect(out.error, ImportError.unsupported);
      expect(store.videos, isEmpty);
      expect(phone.files, isEmpty);
    });

    test('non-video, full storage and unconnected folder all fail cleanly', () async {
      final (phone, _, store) = await connectedWith([]);
      phone.external['content://pick/3'] = ExternalFile('notes.pdf', FakeFile(size: 10), isVideo: false);
      expect((await store.importVideo('content://pick/3')).error, ImportError.notVideo);

      phone.external['content://pick/4'] = ExternalFile('big.mp4', FakeFile(size: 10));
      phone.full = true;
      expect((await store.importVideo('content://pick/4')).error, ImportError.noSpace);
      expect(store.videos, isEmpty);

      final disconnected = newStore(FakeGateway(FakePhone()));
      expect((await disconnected.importVideo('content://pick/4')).error, ImportError.folderNotConnected);
    });

    test('simultaneous imports are serialised and all end up in the manifest', () async {
      final (phone, _, store) = await connectedWith([]);
      for (var i = 0; i < 4; i++) {
        phone.external['content://pick/$i'] = ExternalFile('v$i.mp4', FakeFile(size: 1000 + i));
      }
      final outs = await Future.wait([for (var i = 0; i < 4; i++) store.importVideo('content://pick/$i')]);
      expect(outs.every((o) => o.ok), isTrue);
      expect(VideoManifest.tryParse(phone.manifestMain)!.videos.length, 4);
    });
  });

  group('validation and manifest writes', () {
    test('a video the player rejected stays excluded until a manual refresh re-checks it', () async {
      final (_, _, store) = await connectedWith(['a.mp4']);
      final a = store.videos.single;
      await store.markUnplayable(a.id);
      await store.load();
      expect(store.byId(a.id)!.eligible, isFalse);
      await store.load(recheck: true);
      expect(store.byId(a.id)!.eligible, isTrue);
    });

    test('a failed manifest write does not crash and is retried on the next change', () async {
      final (phone, gw, store) = await connectedWith(['a.mp4']);
      final a = store.videos.single;
      gw.failWrites = true;
      await store.rename(a.id, 'Renamed');
      expect(VideoManifest.tryParse(phone.manifestMain)!.videos.single.title, isNot('Renamed'));
      gw.failWrites = false;
      await store.load();
      expect(VideoManifest.tryParse(phone.manifestMain)!.videos.single.title, 'Renamed');
    });

    test('loading again without changes does not rewrite the manifest', () async {
      final (_, gw, store) = await connectedWith(['a.mp4']);
      await store.load();
      final writes = gw.writeCount;
      await store.load();
      await store.load();
      expect(gw.writeCount, writes);
    });
  });
}
