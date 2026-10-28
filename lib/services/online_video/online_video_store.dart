import 'package:uuid/uuid.dart';

import '../../models/online_video.dart';
import 'online_video_gateway.dart';
import 'video_link.dart';

enum AddKind {
  /// Saved as a new entry.
  added,

  /// The same video was already saved; nothing new was created.
  duplicate,

  /// No web address in the text.
  noUrl,

  /// Not a usable http(s) address.
  invalid,

  /// A video site's front page, not a video.
  homepageOnly,

  /// The phone's database refused (full storage?). Nothing was saved.
  failed,
}

class AddOutcome {
  final AddKind kind;
  final OnlineVideo? video;
  const AddOutcome(this.kind, [this.video]);

  bool get ok => kind == AddKind.added || kind == AddKind.duplicate;
}

/// Saving links: validates the text, recognises the platform, rejects duplicates
/// and stores the entry in the phone's local database.
///
/// Saving never waits for a title, a thumbnail or a playable embed. Those are
/// looked up later, lazily, and their absence never stops a link being saved.
class OnlineVideoStore {
  OnlineVideoStore(this._gw, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final OnlineVideoGateway _gw;
  final Uuid _uuid;

  /// [text] is whatever was pasted or shared ("Look at this https://..." is fine).
  /// [subject] is the sender's title hint from the share menu (may be empty).
  Future<AddOutcome> addFromText(String text, {String subject = '', String? collectionId}) async {
    final parsed = VideoLinkParser.parseText(text);
    final link = parsed.link;
    if (link == null) {
      return AddOutcome(switch (parsed.error) {
        LinkError.homepageOnly => AddKind.homepageOnly,
        LinkError.invalid => AddKind.invalid,
        _ => AddKind.noUrl,
      });
    }

    final res = await _gw.add(
      id: _uuid.v4(),
      url: link.url,
      key: link.key,
      platform: link.platform,
      title: _titleHint(subject),
      thumbUrl: link.directThumbnailUrl,
      collectionId: collectionId,
    );
    switch (res.status) {
      case AddStatus.added:
        return AddOutcome(AddKind.added, res.video);
      case AddStatus.duplicate:
        return AddOutcome(AddKind.duplicate, res.video);
      case AddStatus.failed:
        return const AddOutcome(AddKind.failed);
    }
  }

  /// A share's subject is a useful title for Instagram / Facebook (which give no
  /// preview of their own) but is often just the link again, so that is ignored.
  static String? _titleHint(String subject) {
    final s = subject.trim();
    if (s.isEmpty || s.length > 200) return null;
    if (VideoLinkParser.extractUrl(s) != null) return null;
    return s;
  }

  /// Message shown to the person for a result.
  static String message(AddOutcome o) {
    switch (o.kind) {
      case AddKind.added:
        return 'Saved to Online videos.';
      case AddKind.duplicate:
        return 'Already in your Online videos.';
      case AddKind.noUrl:
        return "That doesn't contain a video link. Share or paste a link that starts with https://";
      case AddKind.invalid:
        return "That link doesn't look right. Check it and try again.";
      case AddKind.homepageOnly:
        return 'That is a website’s front page, not a video. Open the video and share its link.';
      case AddKind.failed:
        return 'Could not save the link. Please try again.';
    }
  }
}
