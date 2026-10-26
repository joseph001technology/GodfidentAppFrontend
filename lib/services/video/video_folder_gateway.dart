import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Why the Godfident folder cannot be used right now.
enum FolderProblem {
  /// Nothing connected yet: first launch, or a fresh install (Android drops the
  /// folder permission on uninstall, the folder and videos stay on the phone).
  notConnected,

  /// Android revoked the permission we had saved.
  accessLost,

  /// The folder was deleted or renamed outside Godfident.
  folderMissing,
}

class FolderStatus {
  final bool connected;
  final FolderProblem? problem;

  /// Human-readable location, normally `Movies/Godfident`.
  final String folderPath;

  const FolderStatus.ok({this.folderPath = 'Movies/Godfident'})
      : connected = true,
        problem = null;

  const FolderStatus.problem(FolderProblem this.problem, {this.folderPath = 'Movies/Godfident'}) : connected = false;
}

class FolderFile {
  final String name;
  final String uri;
  final int size;
  final int lastModified;

  const FolderFile({required this.name, required this.uri, required this.size, this.lastModified = 0});
}

class ProbeResult {
  final int durationMs;

  /// The platform could open it and it has a video track.
  final bool playable;

  const ProbeResult({required this.durationMs, required this.playable});

  static const unplayable = ProbeResult(durationMs: 0, playable: false);
}

class RawManifest {
  final String? main;
  final String? tmp;

  const RawManifest({this.main, this.tmp});
}

class PickResult {
  final bool ok;

  /// `cancelled`, `wrong_folder`, `no_access`, `failed` when [ok] is false.
  final String? error;

  const PickResult({required this.ok, this.error});
}

class ImportResult {
  final bool ok;
  final String? name;
  final String? uri;
  final int size;

  /// The same file (same name and size) was already in the folder: nothing copied.
  final bool duplicate;

  /// `not_video`, `no_space`, `copy_failed`, `no_folder` when [ok] is false.
  final String? error;

  const ImportResult({required this.ok, this.name, this.uri, this.size = 0, this.duplicate = false, this.error});
}

/// Everything the library needs from Android's folder APIs. Kept as an
/// interface so the logic can be tested without a phone.
abstract class VideoFolderGateway {
  Future<FolderStatus> status();

  /// Opens Android's folder picker pointed at Movies/Godfident.
  Future<PickResult> pickFolder();

  /// Android's file chooser for videos to add. Returns content uris (empty if cancelled).
  Future<List<String>> pickVideoFiles();

  /// Videos directly inside the Godfident folder. Throws if the folder is unreachable.
  Future<List<FolderFile>> listVideos();

  /// A small JPEG preview frame, or null if one cannot be made.
  Future<Uint8List?> thumbnail(String uri);

  /// Never throws: failures are reported as [ProbeResult.unplayable].
  Future<ProbeResult> probe(String uri);

  Future<RawManifest> readManifest();

  /// Writes atomically (temp file, then swap). Returns false on failure.
  Future<bool> writeManifest(String text);

  /// Copies a picked/recorded/downloaded file INTO the Godfident folder.
  Future<ImportResult> importVideo({required String sourceUri, String? name});

  /// Permanently deletes one file from the folder. Returns false on failure.
  Future<bool> deleteFile(String name);
}

/// Talks to VideoFolderPlugin.kt. Nothing here touches the network.
class NativeVideoFolderGateway implements VideoFolderGateway {
  static const _ch = MethodChannel('com.godfident/video_folder');

  Future<Map<String, Object?>?> _map(String method, [Object? args]) async {
    final r = await _ch.invokeMethod<Map<Object?, Object?>>(method, args);
    return r?.map((k, v) => MapEntry('$k', v));
  }

  @override
  Future<FolderStatus> status() async {
    try {
      final m = await _map('status');
      final path = (m?['folderPath'] as String?) ?? 'Movies/Godfident';
      if (m?['connected'] == true) return FolderStatus.ok(folderPath: path);
      final problem = switch (m?['reason']) {
        'access_lost' => FolderProblem.accessLost,
        'folder_missing' => FolderProblem.folderMissing,
        _ => FolderProblem.notConnected,
      };
      return FolderStatus.problem(problem, folderPath: path);
    } on PlatformException {
      return const FolderStatus.problem(FolderProblem.notConnected);
    } on MissingPluginException {
      return const FolderStatus.problem(FolderProblem.notConnected);
    }
  }

  @override
  Future<PickResult> pickFolder() async {
    try {
      final m = await _map('pickFolder');
      return PickResult(ok: m?['ok'] == true, error: m?['error'] as String?);
    } on PlatformException {
      return const PickResult(ok: false, error: 'failed');
    }
  }

  @override
  Future<List<String>> pickVideoFiles() async {
    try {
      final raw = await _ch.invokeMethod<List<Object?>>('pickVideos') ?? const [];
      return [for (final e in raw) '$e'];
    } on PlatformException {
      return const [];
    }
  }

  @override
  Future<List<FolderFile>> listVideos() async {
    final raw = await _ch.invokeMethod<List<Object?>>('listVideos') ?? const [];
    return [
      for (final e in raw.whereType<Map>())
        FolderFile(
          name: '${e['name']}',
          uri: '${e['uri']}',
          size: (e['size'] as num?)?.toInt() ?? 0,
          lastModified: (e['lastModified'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  @override
  Future<Uint8List?> thumbnail(String uri) async {
    try {
      return await _ch.invokeMethod<Uint8List>('thumbnail', {'uri': uri});
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<ProbeResult> probe(String uri) async {
    try {
      final m = await _map('probe', {'uri': uri});
      return ProbeResult(durationMs: (m?['durationMs'] as num?)?.toInt() ?? 0, playable: m?['playable'] == true);
    } on PlatformException {
      return ProbeResult.unplayable;
    }
  }

  @override
  Future<RawManifest> readManifest() async {
    try {
      final m = await _map('readManifest');
      return RawManifest(main: m?['main'] as String?, tmp: m?['tmp'] as String?);
    } on PlatformException {
      return const RawManifest();
    }
  }

  @override
  Future<bool> writeManifest(String text) async {
    try {
      return await _ch.invokeMethod<bool>('writeManifest', {'text': text}) ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<ImportResult> importVideo({required String sourceUri, String? name}) async {
    try {
      final m = await _map('importVideo', {'sourceUri': sourceUri, 'name': name});
      return ImportResult(
        ok: m?['ok'] == true,
        name: m?['name'] as String?,
        uri: m?['uri'] as String?,
        size: (m?['size'] as num?)?.toInt() ?? 0,
        duplicate: m?['duplicate'] == true,
        error: m?['error'] as String?,
      );
    } on PlatformException {
      return const ImportResult(ok: false, error: 'copy_failed');
    }
  }

  @override
  Future<bool> deleteFile(String name) async {
    try {
      return await _ch.invokeMethod<bool>('deleteFile', {'name': name}) ?? false;
    } on PlatformException {
      return false;
    }
  }
}
