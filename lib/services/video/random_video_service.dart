import '../../models/local_video.dart';
import 'video_library_store.dart';
import 'video_selector.dart';

enum NoVideoReason {
  /// The Godfident folder is not connected (fresh install, permission lost, folder deleted).
  folderNotConnected,

  /// No video is eligible (empty library, all missing/excluded/unplayable).
  noEligibleVideo,
}

class VideoPick {
  final LocalVideo? video;
  final NoVideoReason? reason;

  const VideoPick.found(LocalVideo this.video) : reason = null;
  const VideoPick.none(NoVideoReason this.reason) : video = null;

  bool get found => video != null;
}

/// Chooses which local video to show when something is blocked.
///
/// Flow used by the player:
///   1. `next()`                    -> a video (or why there is none)
///   2. open it; on failure `reportFailure(id)` then `next(skip: failedIds)`
///   3. when playback has started `confirmPlayed(id)`
///
/// Every failure removes that video from the candidates, so the retry loop
/// always ends. Nothing here uses the network.
class RandomVideoService {
  RandomVideoService(this._store, {VideoSelector? selector}) : _selector = selector ?? VideoSelector();

  final VideoLibraryStore _store;
  final VideoSelector _selector;

  Future<VideoPick> next({Set<String> skip = const {}}) async {
    final state = await _store.load(); // re-check the folder: files may have changed
    if (!state.folder.connected) return const VideoPick.none(NoVideoReason.folderNotConnected);

    final eligible = {for (final v in _store.eligibleVideos) v.id};
    final plan = _selector.plan(eligible: eligible, state: _store.cycle);
    if (plan.state != _store.cycle) await _store.saveCycle(plan.state);

    for (final id in plan.candidates) {
      if (skip.contains(id)) continue;
      final v = _store.byId(id);
      if (v != null && v.eligible) return VideoPick.found(v);
    }
    return const VideoPick.none(NoVideoReason.noEligibleVideo);
  }

  /// Call once playback has actually started (not merely when a pick was made).
  Future<void> confirmPlayed(String id) async {
    await _store.recordPlayback(id, _selector.markPlayed(_store.cycle, id));
  }

  /// The player could not open [id].
  Future<void> reportFailure(String id) => _store.markUnplayable(id);
}
