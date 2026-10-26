import 'dart:typed_data';

import 'package:godfident/services/video/video_folder_gateway.dart';
import 'package:godfident/services/video/video_library_store.dart';

class FakeFile {
  int size;
  int durationMs;
  bool playable;
  FakeFile({required this.size, this.durationMs = 60000, this.playable = true});
}

class ExternalFile {
  final String name;
  final FakeFile file;
  final bool isVideo;
  ExternalFile(this.name, this.file, {this.isVideo = true});
}

/// The phone's shared storage. It outlives the app: tests "uninstall" Godfident
/// by calling [uninstallApp] and creating brand-new objects over the same phone.
class FakePhone {
  final Map<String, FakeFile> files = {};
  final Map<String, ExternalFile> external = {};
  String? manifestMain;
  String? manifestTmp;

  /// Android's permission to the folder. Lost on uninstall; files are not.
  bool granted = false;
  bool folderExists = false;
  int foldersCreated = 0;
  bool full = false;

  void uninstallApp() => granted = false;

  int _nextSize = 1000;

  /// Default sizes are all different so tests never hit an accidental "same size" rename match.
  void addVideo(String name, {int? size, int durationMs = 60000, bool playable = true}) {
    files[name] = FakeFile(size: size ?? (_nextSize += 137), durationMs: durationMs, playable: playable);
  }
}

const _prefix = 'fake://folder/';

class FakeGateway implements VideoFolderGateway {
  FakeGateway(this.phone);

  final FakePhone phone;
  bool failWrites = false;
  bool failList = false;
  bool failDelete = false;
  int writeCount = 0;
  int probeCount = 0;

  @override
  Future<FolderStatus> status() async {
    if (!phone.granted) return const FolderStatus.problem(FolderProblem.notConnected);
    if (!phone.folderExists) return const FolderStatus.problem(FolderProblem.folderMissing);
    return const FolderStatus.ok();
  }

  @override
  Future<PickResult> pickFolder() async {
    phone.granted = true;
    if (!phone.folderExists) {
      phone.folderExists = true;
      phone.foldersCreated++;
    }
    return const PickResult(ok: true);
  }

  @override
  Future<List<String>> pickVideoFiles() async => phone.external.keys.toList();

  @override
  Future<List<FolderFile>> listVideos() async {
    if (failList) throw StateError('folder unreachable');
    return [
      for (final e in phone.files.entries) FolderFile(name: e.key, uri: '$_prefix${e.key}', size: e.value.size),
    ];
  }

  @override
  Future<Uint8List?> thumbnail(String uri) async => null;

  @override
  Future<ProbeResult> probe(String uri) async {
    probeCount++;
    final f = phone.files[uri.startsWith(_prefix) ? uri.substring(_prefix.length) : uri];
    if (f == null || !f.playable) return ProbeResult.unplayable;
    return ProbeResult(durationMs: f.durationMs, playable: true);
  }

  @override
  Future<RawManifest> readManifest() async => RawManifest(main: phone.manifestMain, tmp: phone.manifestTmp);

  @override
  Future<bool> writeManifest(String text) async {
    if (failWrites) return false;
    writeCount++;
    phone.manifestMain = text;
    phone.manifestTmp = null;
    return true;
  }

  @override
  Future<ImportResult> importVideo({required String sourceUri, String? name}) async {
    final src = phone.external[sourceUri];
    if (src == null) return const ImportResult(ok: false, error: 'copy_failed');
    if (!src.isVideo) return const ImportResult(ok: false, error: 'not_video');
    if (phone.full) return const ImportResult(ok: false, error: 'no_space');
    final wanted = name ?? src.name;
    final same = phone.files[wanted];
    if (same != null && same.size == src.file.size) {
      return ImportResult(ok: true, name: wanted, uri: '$_prefix$wanted', size: same.size, duplicate: true);
    }
    var finalName = wanted;
    var n = 1;
    while (phone.files.containsKey(finalName)) {
      final dot = wanted.lastIndexOf('.');
      finalName = dot > 0 ? '${wanted.substring(0, dot)} ($n)${wanted.substring(dot)}' : '$wanted ($n)';
      n++;
    }
    phone.files[finalName] = FakeFile(size: src.file.size, durationMs: src.file.durationMs, playable: src.file.playable);
    return ImportResult(ok: true, name: finalName, uri: '$_prefix$finalName', size: src.file.size);
  }

  @override
  Future<bool> deleteFile(String name) async {
    if (failDelete) return false;
    phone.files.remove(name);
    return true;
  }
}

/// A connected store with deterministic timestamps.
VideoLibraryStore newStore(FakeGateway gw) {
  var t = 1000000;
  return VideoLibraryStore(gw, clock: () => DateTime.fromMillisecondsSinceEpoch(t += 1000));
}

/// A phone that already has [names] in the folder, with the app connected.
Future<(FakePhone, FakeGateway, VideoLibraryStore)> connectedWith(List<String> names) async {
  final phone = FakePhone();
  for (final n in names) {
    phone.addVideo(n);
  }
  final gw = FakeGateway(phone);
  final store = newStore(gw);
  await store.connectFolder();
  return (phone, gw, store);
}
