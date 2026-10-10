import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'music_service.dart';
import 'ringtone_store.dart';
import 'native_alarm.dart';

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
        _remember(_current!);
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
  Future<void> playList(List<Song> songs, int index, {bool loopAll = false}) async {
    if (songs.isEmpty || index < 0 || index >= songs.length) return;
    _sessionStarted = false; // the person chose this themselves
    _isPreview = false;
    _previewTitle = null;
    _error = null;
    _queue = List.unmodifiable(songs);
    _current = songs[index];
    _remember(songs[index]);
    notifyListeners();
    try {
      await player.setLoopMode(loopAll ? LoopMode.all : LoopMode.off);
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

  // ── "last played" + Focus-session music ──────────────────────────────
  static const _kLast = 'music_last_song_v1';
  bool _sessionStarted = false;

  Future<void> _remember(Song s) async {
    try {
      (await SharedPreferences.getInstance()).setString(
        _kLast,
        jsonEncode({
          'id': s.id,
          'title': s.title,
          'artist': s.artist,
          'album': s.album,
          'ms': s.duration.inMilliseconds,
          if (s.uri != null) 'uri': s.uri,
          if (s.asset != null) 'asset': s.asset,
        }),
      );
    } catch (_) {}
  }

  Future<Song?> lastSong() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_kLast);
      if (raw == null) return null;
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final asset = m['asset'] as String?;
      // A bundled track that no longer ships (the old ambient pieces) cannot be replayed.
      if (asset != null && !asset.contains('/ringtones/') && !bundledSongs.any((b) => b.asset == asset)) return null;
      return Song(
        id: m['id'] as String,
        title: m['title'] as String? ?? 'Song',
        artist: m['artist'] as String? ?? '',
        album: m['album'] as String? ?? '',
        duration: Duration(milliseconds: (m['ms'] as num?)?.toInt() ?? 0),
        uri: m['uri'] as String?,
        asset: m['asset'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// The alarm ringtone the person last chose, as a playable song.
  Future<Song?> _ringtoneSong() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString('ringtone_default');
      if (raw == null) return null;
      final t = Ringtone.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      if (t.isDevice) {
        return Song(id: 'rt_${t.uri.hashCode}', title: t.title, artist: 'Ringtone', duration: Duration.zero, uri: t.uri);
      }
      return Song(
          id: 'rt_${t.id}',
          title: t.title,
          artist: 'Ringtone',
          duration: Duration.zero,
          asset: 'assets/audio/ringtones/${t.id}.mp3');
    } catch (_) {
      return null;
    }
  }

  /// A Focus / Prayer session just began: play something calm. If music is
  /// already playing it is left alone. Otherwise: the song played last, else
  /// the alarm ringtone, else a bundled track. It loops until the session ends.
  Future<void> startForSession() async {
    try {
      if (player.playing && current != null) return;
      final song = await lastSong() ?? await _ringtoneSong() ?? bundledSongs.first;
      final bundledIdx = bundledSongs.indexWhere((b) => b.id == song.id);
      if (bundledIdx >= 0) {
        await playList(bundledSongs, bundledIdx, loopAll: true);
      } else {
        await playList([song], 0, loopAll: true);
      }
      _sessionStarted = true;
    } catch (_) {}
  }

  /// Session over: stop the music only if the session started it.
  Future<void> endSessionMusic() async {
    if (!_sessionStarted) return;
    _sessionStarted = false;
    await stop();
  }

  Future<void> pauseForFreeze() async {
    try {
      if (player.playing) await player.pause();
    } catch (_) {}
  }

  Future<void> resumeAfterFreeze() async {
    try {
      if (current != null && !player.playing) await player.play();
    } catch (_) {}
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
  String? get previewTitle => _previewing ? _previewTitle : null;
  String? get previewError => _previewError;

  bool _previewing = false;

  /// "assets/audio/ringtones/bell.mp3" -> the bundled raw resource "godfident_bell".
  Future<void> previewAsset(String assetPath, String title) {
    final name = assetPath.split('/').last.split('.').first;
    return _nativePreview('raw:godfident_$name', title);
  }

  Future<void> previewUri(String uri, String title) => _nativePreview(uri, title);

  /// Plays through a separate native player, so the music player, its queue and
  /// the mini player are NOT touched: music is simply ducked while the sample plays.
  Future<void> _nativePreview(String sound, String title) async {
    _previewTitle = title;
    _previewError = null;
    _previewing = true;
    notifyListeners();
    final ok = await NativeAlarm.previewSound(sound);
    if (!ok) {
      _previewing = false;
      _previewTitle = null;
      _previewError = 'This sound could not be played.';
    }
    notifyListeners();
  }

  Future<void> stopPreview() async {
    if (!_previewing) return;
    _previewing = false;
    _previewTitle = null;
    _previewError = null;
    await NativeAlarm.stopPreview();
    notifyListeners();
  }
}
