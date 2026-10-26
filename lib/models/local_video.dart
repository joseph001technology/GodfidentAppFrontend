import 'dart:convert';

import 'package:collection/collection.dart';

/// Where a library video came from. `discovered` = found in the Godfident
/// folder (for example after a reinstall) without Godfident having copied it.
enum VideoSource { imported, downloaded, recorded, discovered }

VideoSource _sourceFrom(Object? v) {
  for (final s in VideoSource.values) {
    if (s.name == v) return s;
  }
  return VideoSource.discovered;
}

/// One video in the on-device library.
///
/// Only the fields in [toJson] are written to the manifest. [uri] and
/// [available] are looked up from the folder every time and never stored.
class LocalVideo {
  /// Permanent UUID, generated once. Never derived from list position.
  final String id;
  final String title;

  /// File name inside Movies/Godfident/ (the folder is flat).
  final String fileName;
  final int fileSize;
  final int durationMs;
  final VideoSource source;
  final DateTime dateAdded;
  final DateTime? lastPlayedAt;

  /// The user opted this video out of random redirection.
  final bool excluded;

  /// The user removed it from the library. The file is NOT deleted; the record
  /// is kept so a refresh does not silently re-add the file.
  final bool removed;

  /// Result of the latest media validation (can the platform open it?).
  final bool playable;

  // ---- runtime only ----
  final String? uri;
  final bool available;

  const LocalVideo({
    required this.id,
    required this.title,
    required this.fileName,
    required this.fileSize,
    required this.durationMs,
    required this.source,
    required this.dateAdded,
    this.lastPlayedAt,
    this.excluded = false,
    this.removed = false,
    this.playable = true,
    this.uri,
    this.available = false,
  });

  /// Everything the random redirect requires.
  bool get eligible => available && playable && !excluded && !removed && uri != null;

  LocalVideo copyWith({
    String? title,
    String? fileName,
    int? fileSize,
    int? durationMs,
    DateTime? lastPlayedAt,
    bool? excluded,
    bool? removed,
    bool? playable,
    String? uri,
    bool clearUri = false,
    bool? available,
  }) {
    return LocalVideo(
      id: id,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      durationMs: durationMs ?? this.durationMs,
      source: source,
      dateAdded: dateAdded,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      excluded: excluded ?? this.excluded,
      removed: removed ?? this.removed,
      playable: playable ?? this.playable,
      uri: clearUri ? null : (uri ?? this.uri),
      available: available ?? this.available,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'fileName': fileName,
        'fileSize': fileSize,
        'durationMs': durationMs,
        'source': source.name,
        'dateAdded': dateAdded.millisecondsSinceEpoch,
        'lastPlayedAt': lastPlayedAt?.millisecondsSinceEpoch,
        'excluded': excluded,
        'removed': removed,
        'playable': playable,
      };

  /// Throws [FormatException] when the record is unusable (no id / file name).
  factory LocalVideo.fromJson(Map<String, Object?> j) {
    final id = j['id'];
    final name = j['fileName'];
    if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
      throw const FormatException('video record without id or fileName');
    }
    final added = j['dateAdded'];
    final played = j['lastPlayedAt'];
    return LocalVideo(
      id: id,
      title: (j['title'] is String && (j['title'] as String).trim().isNotEmpty)
          ? j['title'] as String
          : name,
      fileName: name,
      fileSize: (j['fileSize'] as num?)?.toInt() ?? 0,
      durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
      source: _sourceFrom(j['source']),
      dateAdded: DateTime.fromMillisecondsSinceEpoch(added is num ? added.toInt() : 0),
      lastPlayedAt: played is num ? DateTime.fromMillisecondsSinceEpoch(played.toInt()) : null,
      excluded: j['excluded'] == true,
      removed: j['removed'] == true,
      playable: j['playable'] != false,
    );
  }
}

/// Compact state of the non-repeating "shuffled bag".
class CycleState {
  /// The shuffled order of the current cycle.
  final List<String> order;

  /// Ids already played successfully in the current cycle.
  final List<String> played;

  /// The most recent successfully played id (survives a cycle reset).
  final String? previousId;

  const CycleState({this.order = const [], this.played = const [], this.previousId});

  static const empty = CycleState();

  Map<String, Object?> toJson() => {'order': order, 'played': played, 'previousId': previousId};

  factory CycleState.fromJson(Object? j) {
    if (j is! Map) return empty;
    List<String> strings(Object? v) => v is List ? v.whereType<String>().toList() : <String>[];
    final p = j['previousId'];
    return CycleState(order: strings(j['order']), played: strings(j['played']), previousId: p is String ? p : null);
  }

  @override
  bool operator ==(Object other) =>
      other is CycleState &&
      other.previousId == previousId &&
      const ListEquality<String>().equals(other.order, order) &&
      const ListEquality<String>().equals(other.played, played);

  @override
  int get hashCode => Object.hash(previousId, const ListEquality<String>().hash(order), const ListEquality<String>().hash(played));
}

/// The file stored in Movies/Godfident/ that keeps video ids, titles,
/// exclusions and playback history alive across reinstalls and accounts.
/// It never leaves the phone.
class VideoManifest {
  static const currentVersion = 1;

  final int version;

  /// Identifies this library. Stable across reinstalls (read back from the file).
  final String libraryId;
  final DateTime createdAt;
  final List<LocalVideo> videos;
  final CycleState cycle;

  const VideoManifest({
    this.version = currentVersion,
    required this.libraryId,
    required this.createdAt,
    this.videos = const [],
    this.cycle = CycleState.empty,
  });

  VideoManifest copyWith({List<LocalVideo>? videos, CycleState? cycle}) => VideoManifest(
        version: version,
        libraryId: libraryId,
        createdAt: createdAt,
        videos: videos ?? this.videos,
        cycle: cycle ?? this.cycle,
      );

  Map<String, Object?> toJson() => {
        'version': version,
        'libraryId': libraryId,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'videos': [for (final v in videos) v.toJson()],
        'cycle': cycle.toJson(),
      };

  /// Text without any timestamp: used to decide whether a rewrite is needed.
  String encodeBody() => jsonEncode(toJson());

  /// Text to store. [savedAt] lets a reader choose the newest of two copies.
  String encode(DateTime savedAt) => jsonEncode({...toJson(), 'savedAt': savedAt.millisecondsSinceEpoch});

  /// Returns null for anything that is not a usable manifest (corrupt, empty,
  /// wrong shape). Individual bad records are skipped, not fatal.
  static VideoManifest? tryParse(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    try {
      final j = jsonDecode(text);
      if (j is! Map) return null;
      final version = j['version'];
      final libraryId = j['libraryId'];
      final list = j['videos'];
      if (version is! num || libraryId is! String || libraryId.isEmpty || list is! List) return null;
      final videos = <LocalVideo>[];
      final seen = <String>{};
      for (final item in list) {
        if (item is! Map) continue;
        try {
          final v = LocalVideo.fromJson(item.map((k, v) => MapEntry('$k', v)));
          if (seen.add(v.id)) videos.add(v);
        } on FormatException {
          continue;
        }
      }
      final created = j['createdAt'];
      return VideoManifest(
        version: version.toInt(),
        libraryId: libraryId,
        createdAt: DateTime.fromMillisecondsSinceEpoch(created is num ? created.toInt() : 0),
        videos: videos,
        cycle: CycleState.fromJson(j['cycle']),
      );
    } catch (_) {
      return null;
    }
  }

  /// `savedAt` of a stored text, or 0.
  static int savedAtOf(String? text) {
    try {
      final j = jsonDecode(text ?? '');
      final s = j is Map ? j['savedAt'] : null;
      return s is num ? s.toInt() : 0;
    } catch (_) {
      return 0;
    }
  }
}
