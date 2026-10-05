import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'music_service.dart';

/// The ONE audio player of the whole app.
///
/// It used to live inside the Music screen and was disposed the moment you
/// left that tab, so the music stopped. Now it lives here for the life of the
/// app, and `just_audio_background` runs it inside an Android media
/// foreground service, so playback continues when you:
///   * switch to another tab,
///   * lock the phone,
///   * press Home or swipe Godfident away from recents,
/// and can be controlled from the notification / lock screen.
///
/// Only a single AudioPlayer may exist with just_audio_background, so the
/// ringtone preview in the reminder editor also goes through this class.
class MusicController extends ChangeNotifier {
  MusicController._() {
    player.currentIndexStream.listen((i) {
      if (_isPreview) return;
      if (i != null && i >= 0 && i < _queue.length && _queue[i] != _current) {
        _current = _queue[i];
        notifyListeners();
      }
    });
    player.playerStateStream.listen((_) => notifyListeners());
    player.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace st) {
      _error = 'This track could not be played (the file may be damaged or unsupported).';
      notifyListeners();
    });
  }

  static final MusicController instance = MusicController._();

  final AudioPlayer player = AudioPlayer();

  List<Song> _queue = const [];
  Song? _current;
  String? _error;
  bool _isPreview = false;

  List<Song> get queue => _queue;
  Song? get current => _isPreview ? null : _current;
  String? get error => _error;
  bool get isPlaying => player.playing;
  bool get hasNext => player.hasNext;
  bool get hasPrevious => player.hasPrevious;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  AudioSource _sourceFor(Song s) {
    final tag = MediaItem(
      id: s.id,
      title: s.title,
      artist: s.artist,
      album: s.album.isEmpty ? 'Godfident' : s.album,
      duration: s.duration == Duration.zero ? null : s.duration,
    );
    return s.isDevice
        ? AudioSource.uri(Uri.parse(s.uri!), tag: tag)
        : AudioSource.asset(s.asset!, tag: tag);
  }

  /// Plays [songs][index] and queues the rest of the list, so it carries on
  /// to the next song by itself - also with the app in the background.
  Future<void> playList(List<Song> songs, int index) async {
    if (songs.isEmpty || index < 0 || index >= songs.length) return;
    _isPreview = false;
    _previewTitle = null;
    _error = null;
    _queue = List.unmodifiable(songs);
    _current = songs[index];
    notifyListeners();
    try {
      await player.setLoopMode(LoopMode.off);
      await player.setAudioSource(
        // ignore: deprecated_member_use
        ConcatenatingAudioSource(children: [for (final s in songs) _sourceFor(s)]),
        initialIndex: index,
        initialPosition: Duration.zero,
      );
      await player.play();
    } catch (_) {
      _error = '"${songs[index].title}" could not be played (the file may be damaged or unsupported).';
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> next() async {
    if (player.hasNext) await player.seekToNext();
  }

  Future<void> previous() async {
    if (player.position > const Duration(seconds: 3) || !player.hasPrevious) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
  }

  Future<void> seek(Duration d) => player.seek(d);

  /// Stops playback and hides the mini player (the close button).
  Future<void> stop() async {
    await player.stop();
    _queue = const [];
    _current = null;
    _isPreview = false;
    notifyListeners();
  }

  // ── ringtone preview (one player only, so it shares this one) ────────
  String? _previewTitle;
  String? _previewError;

  /// Title of the ringtone being previewed right now, or null.
  String? get previewTitle => _isPreview && player.playing ? _previewTitle : null;
  String? get previewError => _previewError;

  Future<void> previewAsset(String assetPath, String title) => _preview(
        title,
        () => AudioSource.asset(assetPath, tag: MediaItem(id: 'preview_$assetPath', title: title, album: 'Ringtone preview')),
      );

  Future<void> previewUri(String uri, String title) => _preview(
        title,
        () => AudioSource.uri(Uri.parse(uri), tag: MediaItem(id: 'preview_$uri', title: title, album: 'Ringtone preview')),
      );

  /// Starts playing at once and keeps playing (looping) until another song is
  /// chosen, [stopPreview] is called, or the picker is closed.
  Future<void> _preview(String title, AudioSource Function() build) async {
    _isPreview = true;
    _previewTitle = title;
    _previewError = null;
    _queue = const [];
    _current = null;
    notifyListeners();
    try {
      await player.stop();
      await player.setAudioSource(build());
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(1.0);
      // Do not await: play() only completes when playback ends.
      player.play();
    } catch (e) {
      _previewError = 'This sound could not be played.';
      notifyListeners();
    }
  }

  Future<void> stopPreview() async {
    if (!_isPreview) return;
    _isPreview = false;
    _previewTitle = null;
    _previewError = null;
    try {
      await player.setLoopMode(LoopMode.off);
      await player.stop();
    } catch (_) {}
    notifyListeners();
  }
}
