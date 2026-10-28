/// Online Videos: links to videos that stay on their own platform.
///
/// Nothing here is a video file. A saved entry is only a reference (the link,
/// the platform, a title and a thumbnail address when one is known). The
/// library lives in a local database on the phone and is never sent to the
/// Godfident server.
library;

/// Where a saved link comes from. Detected from the link's address.
enum VideoPlatform {
  youtube('youtube', 'YouTube'),
  instagram('instagram', 'Instagram'),
  tiktok('tiktok', 'TikTok'),
  facebook('facebook', 'Facebook'),
  vimeo('vimeo', 'Vimeo'),
  other('other', 'Web');

  const VideoPlatform(this.id, this.label);

  /// Stored in the database.
  final String id;

  /// Shown to the person.
  final String label;

  static VideoPlatform fromId(String? id) {
    for (final p in VideoPlatform.values) {
      if (p.id == id) return p;
    }
    return VideoPlatform.other;
  }
}

/// How far the one-time title/thumbnail lookup for a video has got.
/// It is asked at most once per video (see LinkMetadataService), never in bulk.
class MetaState {
  MetaState._();

  /// Not looked up yet (or the last attempt only failed because of the network).
  static const int pending = 0;

  /// Looked up successfully.
  static const int done = 1;

  /// The platform does not offer a preview for this link, or the video is
  /// private / removed. Only a manual "Refresh preview" tries again.
  static const int unavailable = 2;
}

class OnlineVideo {
  final String id;

  /// The cleaned link that is opened and played.
  final String url;
  final VideoPlatform platform;

  /// Title from the platform, or the one the person typed. May be null.
  final String? title;

  /// Address of a preview picture on the platform's servers. May be null or expired.
  final String? thumbUrl;

  /// null = not in a collection.
  final String? collectionId;
  final DateTime addedAt;
  final int metaState;

  /// The person renamed it: a platform title must never overwrite that.
  final bool titleEdited;

  const OnlineVideo({
    required this.id,
    required this.url,
    required this.platform,
    this.title,
    this.thumbUrl,
    this.collectionId,
    required this.addedAt,
    this.metaState = MetaState.pending,
    this.titleEdited = false,
  });

  String get displayTitle {
    final t = title?.trim() ?? '';
    return t.isEmpty ? '${platform.label} video' : t;
  }

  factory OnlineVideo.fromMap(Map<dynamic, dynamic> m) => OnlineVideo(
        id: m['id'] as String,
        url: m['url'] as String,
        platform: VideoPlatform.fromId(m['platform'] as String?),
        title: m['title'] as String?,
        thumbUrl: m['thumbUrl'] as String?,
        collectionId: m['collectionId'] as String?,
        addedAt: DateTime.fromMillisecondsSinceEpoch((m['addedAt'] as num?)?.toInt() ?? 0),
        metaState: (m['metaState'] as num?)?.toInt() ?? MetaState.pending,
        titleEdited: ((m['titleEdited'] as num?)?.toInt() ?? 0) == 1,
      );

  OnlineVideo copyWith({
    String? title,
    String? thumbUrl,
    String? collectionId,
    bool clearCollection = false,
    int? metaState,
    bool? titleEdited,
  }) =>
      OnlineVideo(
        id: id,
        url: url,
        platform: platform,
        title: title ?? this.title,
        thumbUrl: thumbUrl ?? this.thumbUrl,
        collectionId: clearCollection ? null : (collectionId ?? this.collectionId),
        addedAt: addedAt,
        metaState: metaState ?? this.metaState,
        titleEdited: titleEdited ?? this.titleEdited,
      );
}

class OnlineCollection {
  final String id;
  final String name;
  final int count;

  const OnlineCollection({required this.id, required this.name, this.count = 0});

  factory OnlineCollection.fromMap(Map<dynamic, dynamic> m) => OnlineCollection(
        id: m['id'] as String,
        name: m['name'] as String,
        count: (m['count'] as num?)?.toInt() ?? 0,
      );
}

/// One page of saved videos read from the local database.
class VideoPage {
  final List<OnlineVideo> items;
  final bool hasMore;

  /// How many videos match the current filter in total (not just this page).
  final int total;

  const VideoPage({this.items = const [], this.hasMore = false, this.total = 0});
}
