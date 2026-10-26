import 'dart:async';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../models/local_video.dart';
import 'video_folder_gateway.dart';

class LibraryState {
  final FolderStatus folder;
  final List<LocalVideo> videos;

  /// An existing manifest was found in the folder and used (ids/history kept).
  final bool manifestRecovered;

  /// Videos were found but no usable manifest: the library was rebuilt from the
  /// files. Titles come from file names; ids are new; history starts empty.
  final bool manifestRebuilt;

  const LibraryState({
    required this.folder,
    this.videos = const [],
    this.manifestRecovered = false,
    this.manifestRebuilt = false,
  });

  int get eligibleCount => videos.where((v) => v.eligible).length;
}

enum ImportError { folderNotConnected, notVideo, noSpace, copyFailed, unsupported }

class ImportOutcome {
  final LocalVideo? video;
  final ImportError? error;

  /// The file was already in the library/folder; nothing new was copied.
  final bool duplicate;

  const ImportOutcome({this.video, this.error, this.duplicate = false});

  bool get ok => video != null;
}

class ConnectOutcome {
  final PickResult pick;
  final LibraryState? state;

  const ConnectOutcome(this.pick, this.state);
}

/// The on-device video library.
///
/// The videos live in the public folder Movies/Godfident/ (visible in Gallery),
/// and so does the manifest that remembers ids, titles, exclusions and playback
/// history. Nothing is account-specific: logging in with another account, or
/// reinstalling, finds the same folder and the same manifest. Nothing is ever
/// sent to a server.
class VideoLibraryStore {
  VideoLibraryStore(this._gw, {Uuid? uuid, DateTime Function()? clock})
      : _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final VideoFolderGateway _gw;
  final Uuid _uuid;
  final DateTime Function() _clock;

  VideoManifest? _manifest;
  FolderStatus _folder = const FolderStatus.problem(FolderProblem.notConnected);
  String? _lastBody; // manifest body last written (or read); null = must write
  Future<void> _tail = Future.value();

  // ---------------------------------------------------------------- reads

  FolderStatus get folder => _folder;

  /// Videos the user can see (removed ones are hidden), newest first.
  List<LocalVideo> get videos {
    final list = [for (final v in _manifest?.videos ?? const <LocalVideo>[]) if (!v.removed) v];
    list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return list;
  }

  List<LocalVideo> get eligibleVideos => [for (final v in _manifest?.videos ?? const <LocalVideo>[]) if (v.eligible) v];

  LocalVideo? byId(String id) {
    for (final v in _manifest?.videos ?? const <LocalVideo>[]) {
      if (v.id == id) return v;
    }
    return null;
  }

  CycleState get cycle => _manifest?.cycle ?? CycleState.empty;

  String? get libraryId => _manifest?.libraryId;

  // ---------------------------------------------------------------- serialisation

  /// Runs library operations one at a time so manifest writes never interleave.
  Future<T> _serial<T>(Future<T> Function() op) {
    final c = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        c.complete(await op());
      } catch (e, s) {
        c.completeError(e, s);
      }
    });
    return c.future;
  }

  // ---------------------------------------------------------------- load / refresh

  /// Checks the folder, reads the manifest (first time only) and reconciles it
  /// with the files that are really there. Safe to call as often as needed.
  ///
  /// [recheck] re-validates videos previously marked unplayable (use it for a
  /// manual "Refresh"; automatic loads leave them excluded so a file the player
  /// rejected is not retried on every blocked-access event).
  Future<LibraryState> load({bool recheck = false}) => _serial(() => _load(recheck: recheck));

  Future<LibraryState> _load({bool recheck = false}) async {
    _folder = await _gw.status();
    if (!_folder.connected) {
      _manifest = null;
      _lastBody = null;
      return LibraryState(folder: _folder);
    }

    var recovered = false;
    var fresh = false;
    if (_manifest == null) {
      final raw = await _gw.readManifest();
      final parsed = _chooseManifest(raw);
      if (parsed != null) {
        _manifest = parsed;
        // If the main file was unreadable (interrupted save) rewrite it right away.
        _lastBody = VideoManifest.tryParse(raw.main) == null ? null : parsed.encodeBody();
        recovered = true;
      } else {
        _manifest = VideoManifest(libraryId: _uuid.v4(), createdAt: _clock());
        _lastBody = null;
        fresh = true;
      }
    }

    try {
      await _reconcile(recheck);
    } catch (_) {
      // The folder could not be listed (unplugged SD card, permission change...).
      // Treat everything as unavailable rather than crashing; the next load retries.
      _manifest = _manifest!.copyWith(
        videos: [for (final v in _manifest!.videos) v.copyWith(available: false, clearUri: true)],
      );
    }
    await _persist();
    return LibraryState(
      folder: _folder,
      videos: videos,
      manifestRecovered: recovered,
      manifestRebuilt: fresh && _manifest!.videos.isNotEmpty,
    );
  }

  /// Prefers a parseable main manifest; falls back to the temp copy left by an
  /// interrupted save; when both parse, the newer wins.
  VideoManifest? _chooseManifest(RawManifest raw) {
    final a = VideoManifest.tryParse(raw.main);
    final b = VideoManifest.tryParse(raw.tmp);
    if (a != null && b != null) {
      return VideoManifest.savedAtOf(raw.tmp) > VideoManifest.savedAtOf(raw.main) ? b : a;
    }
    return a ?? b;
  }

  Future<void> _reconcile(bool recheck) async {
    final m = _manifest!;
    final files = await _gw.listVideos();
    final fileByName = {for (final f in files) f.name: f};
    final claimed = <String>{};
    final out = <LocalVideo>[];
    final unmatched = <LocalVideo>[];

    // 1. Same file name: same video. Re-validate only when it changed.
    for (final r in m.videos) {
      final f = fileByName[r.fileName];
      if (f != null && !claimed.contains(f.name)) {
        claimed.add(f.name);
        out.add(await _refreshRecord(r, f, recheck));
      } else {
        unmatched.add(r);
      }
    }

    // 2. Renamed in the folder by a file manager: keep the id when exactly one
    //    unclaimed file has the same size AND (if known) the same duration.
    final unclaimed = files.where((f) => !claimed.contains(f.name)).toList();
    for (final r in unmatched) {
      LocalVideo? hit;
      if (r.fileSize > 0) {
        final sameSize = unclaimed.where((f) => f.size == r.fileSize && !claimed.contains(f.name)).toList();
        final rivals = unmatched.where((o) => o.fileSize == r.fileSize).length;
        if (sameSize.length == 1 && rivals == 1) {
          final f = sameSize.first;
          final p = await _gw.probe(f.uri);
          if (r.durationMs == 0 || (p.durationMs - r.durationMs).abs() <= 1000) {
            claimed.add(f.name);
            hit = r.copyWith(
              fileName: f.name,
              uri: f.uri,
              available: true,
              playable: p.playable,
              durationMs: p.durationMs > 0 ? p.durationMs : r.durationMs,
            );
          }
        }
      }
      // 3. Gone (deleted or moved out of the folder): keep the record, but it
      //    is unavailable and therefore never selected.
      out.add(hit ?? r.copyWith(available: false, clearUri: true));
    }

    // 4. Files Godfident has never seen (first run, reinstall without manifest,
    //    or copied in with a file manager): new permanent id.
    for (final f in files) {
      if (claimed.contains(f.name)) continue;
      final p = await _gw.probe(f.uri);
      out.add(LocalVideo(
        id: _uuid.v4(),
        title: _titleFrom(f.name),
        fileName: f.name,
        fileSize: f.size,
        durationMs: p.durationMs,
        source: VideoSource.discovered,
        dateAdded: _clock(),
        playable: p.playable,
        uri: f.uri,
        available: true,
      ));
    }

    _manifest = m.copyWith(videos: out);
  }

  Future<LocalVideo> _refreshRecord(LocalVideo r, FolderFile f, bool recheck) async {
    final changed = r.fileSize != f.size;
    if (changed || (recheck && !r.playable) || (r.playable && r.durationMs == 0)) {
      final p = await _gw.probe(f.uri);
      return r.copyWith(
        fileSize: f.size,
        durationMs: p.durationMs > 0 ? p.durationMs : (changed ? 0 : r.durationMs),
        playable: p.playable,
        uri: f.uri,
        available: true,
      );
    }
    return r.copyWith(uri: f.uri, available: true);
  }

  String _titleFrom(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    return base.trim().isEmpty ? fileName : base;
  }

  // ---------------------------------------------------------------- persistence

  Future<void> _persist() async {
    final m = _manifest;
    if (m == null || !_folder.connected) return;
    final body = m.encodeBody();
    if (body == _lastBody) return;
    final ok = await _gw.writeManifest(m.encode(_clock()));
    _lastBody = ok ? body : null; // on failure try again next time
  }

  // ---------------------------------------------------------------- folder connect

  /// Opens Android's folder picker. After success the library is loaded from
  /// whatever is in the folder: an existing manifest is reused, never duplicated.
  Future<ConnectOutcome> connectFolder() async {
    final pick = await _gw.pickFolder();
    if (!pick.ok) return ConnectOutcome(pick, null);
    return ConnectOutcome(pick, await load());
  }

  // ---------------------------------------------------------------- import

  /// Preview picture for a video (null when unavailable). Read-only, so it is not queued.
  Future<Uint8List?> thumbnail(LocalVideo v) async => v.uri == null ? null : _gw.thumbnail(v.uri!);

  /// Opens Android's video chooser. Pass each result to [importVideo].
  Future<List<String>> pickVideoFiles() => _gw.pickVideoFiles();

  Future<ImportOutcome> importVideo(
    String sourceUri, {
    String? name,
    String? title,
    VideoSource source = VideoSource.imported,
  }) =>
      _serial(() async {
        if (_manifest == null || !_folder.connected) await _load();
        if (!_folder.connected) return const ImportOutcome(error: ImportError.folderNotConnected);

        final r = await _gw.importVideo(sourceUri: sourceUri, name: name);
        if (!r.ok || r.name == null || r.uri == null) {
          return ImportOutcome(
            error: switch (r.error) {
              'not_video' => ImportError.notVideo,
              'no_space' => ImportError.noSpace,
              'no_folder' => ImportError.folderNotConnected,
              _ => ImportError.copyFailed,
            },
          );
        }

        // Same file already in the folder: reuse its record (and bring it back if removed).
        final existing = _recordByFileName(r.name!);
        if (existing != null) {
          final restored = existing.copyWith(removed: false, uri: r.uri, available: true);
          _replace(restored);
          await _persist();
          return ImportOutcome(video: restored, duplicate: true);
        }

        final p = await _gw.probe(r.uri!);
        if (!p.playable) {
          // We just created this copy, so we may remove it. Never register unusable files.
          if (!r.duplicate) await _gw.deleteFile(r.name!);
          return const ImportOutcome(error: ImportError.unsupported);
        }

        final video = LocalVideo(
          id: _uuid.v4(),
          title: (title != null && title.trim().isNotEmpty) ? title.trim() : _titleFrom(r.name!),
          fileName: r.name!,
          fileSize: r.size,
          durationMs: p.durationMs,
          source: source,
          dateAdded: _clock(),
          playable: true,
          uri: r.uri,
          available: true,
        );
        _manifest = _manifest!.copyWith(videos: [..._manifest!.videos, video]);
        await _persist();
        return ImportOutcome(video: video, duplicate: r.duplicate);
      });

  LocalVideo? _recordByFileName(String name) {
    for (final v in _manifest!.videos) {
      if (v.fileName == name) return v;
    }
    return null;
  }

  void _replace(LocalVideo v) {
    _manifest = _manifest!.copyWith(videos: [for (final o in _manifest!.videos) o.id == v.id ? v : o]);
  }

  // ---------------------------------------------------------------- edits

  Future<void> rename(String id, String title) => _serial(() async {
        final v = byId(id);
        final t = title.trim();
        if (v == null || t.isEmpty) return;
        _replace(v.copyWith(title: t));
        await _persist();
      });

  Future<void> setExcluded(String id, bool excluded) => _serial(() async {
        final v = byId(id);
        if (v == null) return;
        _replace(v.copyWith(excluded: excluded));
        await _persist();
      });

  /// Hides the video from Godfident. The file stays in Movies/Godfident/.
  Future<void> removeFromLibrary(String id) => _serial(() async {
        final v = byId(id);
        if (v == null) return;
        _replace(v.copyWith(removed: true));
        await _persist();
      });

  /// Permanently deletes the file. The caller must have confirmed with the user.
  /// Returns false (and keeps the record) when Android refuses.
  Future<bool> deleteFilePermanently(String id) => _serial(() async {
        final v = byId(id);
        if (v == null) return false;
        if (v.available && !await _gw.deleteFile(v.fileName)) return false;
        _manifest = _manifest!.copyWith(videos: [for (final o in _manifest!.videos) if (o.id != id) o]);
        await _persist();
        return true;
      });

  // ---------------------------------------------------------------- playback bookkeeping

  /// Playback really started: remember it (history + cycle) in the manifest.
  Future<void> recordPlayback(String id, CycleState newCycle) => _serial(() async {
        final v = byId(id);
        if (v == null || _manifest == null) return;
        _manifest = _manifest!.copyWith(
          videos: [for (final o in _manifest!.videos) o.id == id ? o.copyWith(lastPlayedAt: _clock()) : o],
          cycle: newCycle,
        );
        await _persist();
      });

  /// The player could not open this video. It stops being eligible until a
  /// refresh re-validates it.
  Future<void> markUnplayable(String id) => _serial(() async {
        final v = byId(id);
        if (v == null) return;
        _replace(v.copyWith(playable: false));
        await _persist();
      });

  Future<void> saveCycle(CycleState c) => _serial(() async {
        if (_manifest == null || _manifest!.cycle == c) return;
        _manifest = _manifest!.copyWith(cycle: c);
        await _persist();
      });
}
