import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A song. Either a file on the phone (content:// [uri]) or a track bundled in the app.
class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String? uri; // device song
  final String? asset; // bundled track
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    required this.duration,
    this.uri,
    this.asset,
  });

  bool get isDevice => uri != null;
}

/// Songs bundled with Godfident: chant-style pieces (original melodies in the
/// old church modes, sung by a synthesized choir with a cathedral reverb) for
/// prayer and rest, plus two public-domain hymn melodies. These are
/// synthesized stand-ins, not recordings of a real choir; pin your own files
/// (Music > Add from phone) to have them listed beside these.
const bundledSongs = <Song>[
  Song(id: 'c_kyrie', title: 'Kyrie Eleison', artist: 'Godfident \u00b7 chant style', album: 'Chants', duration: Duration(seconds: 84), asset: 'assets/audio/chant_kyrie.mp3'),
  Song(id: 'c_veni', title: 'Veni Sancte Spiritus', artist: 'Godfident \u00b7 chant style', album: 'Chants', duration: Duration(seconds: 82), asset: 'assets/audio/chant_veni.mp3'),
  Song(id: 'c_sanctus', title: 'Sanctus', artist: 'Godfident \u00b7 chant style', album: 'Chants', duration: Duration(seconds: 75), asset: 'assets/audio/chant_sanctus.mp3'),
  Song(id: 'c_agnus', title: 'Agnus Dei', artist: 'Godfident \u00b7 chant style', album: 'Chants', duration: Duration(seconds: 72), asset: 'assets/audio/chant_agnus.mp3'),
  Song(id: 'c_gloria', title: 'Gloria Patri', artist: 'Godfident \u00b7 chant style', album: 'Chants', duration: Duration(seconds: 52), asset: 'assets/audio/chant_gloria.mp3'),
  Song(id: 'a_ode_to_joy', title: 'Ode to Joy (Joyful, Joyful)', artist: 'Beethoven \u00b7 public domain', album: 'Hymns', duration: Duration(seconds: 37), asset: 'assets/audio/ode_to_joy.mp3'),
  Song(id: 'a_silent_night', title: 'Silent Night', artist: 'Gruber \u00b7 public domain', album: 'Hymns', duration: Duration(seconds: 43), asset: 'assets/audio/silent_night.mp3'),
];

/// Songs the person pinned (from the phone's music list or the file chooser).
/// They are listed together with the bundled songs, newest pin first.
class PinnedSongs {
  PinnedSongs._();
  static final PinnedSongs instance = PinnedSongs._();
  static const _k = 'pinned_songs_v1';

  Future<List<Song>> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_k);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((m) => Song(
                id: '${m['id']}',
                title: '${m['title']}',
                artist: '${m['artist'] ?? ''}',
                album: 'Pinned',
                duration: Duration(milliseconds: (m['ms'] as num?)?.toInt() ?? 0),
                uri: '${m['uri']}',
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(List<Song> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _k,
      jsonEncode([
        for (final s in list)
          {'id': s.id, 'title': s.title, 'artist': s.artist, 'ms': s.duration.inMilliseconds, 'uri': s.uri},
      ]),
    );
  }

  Future<void> pin(Song s) async {
    if (!s.isDevice) return;
    final list = await load();
    if (list.any((x) => x.id == s.id || x.uri == s.uri)) return;
    await _save([s, ...list]);
  }

  Future<void> unpin(Song s) async {
    final list = await load();
    await _save(list.where((x) => x.id != s.id && x.uri != s.uri).toList());
  }

  /// Opens Android's file chooser (several files allowed) and pins what was chosen.
  Future<int> pickAndPin() async {
    if (!Platform.isAndroid) return 0;
    final raw = await DeviceMusicService._ch.invokeMethod<List<Object?>>('pickAudioFiles') ?? const [];
    var n = 0;
    for (final m in raw.whereType<Map>()) {
      final uri = '${m['uri']}';
      await pin(Song(
        id: 'p_${uri.hashCode.abs()}',
        title: '${m['title']}',
        artist: '${m['artist']}',
        duration: Duration(milliseconds: (m['durationMs'] as num?)?.toInt() ?? 0),
        uri: uri,
      ));
      n++;
    }
    return n;
  }
}

/// Reads the audio files that are really on this phone (Android MediaStore).
class DeviceMusicService {
  DeviceMusicService._();
  static final DeviceMusicService instance = DeviceMusicService._();
  static const _ch = MethodChannel('com.godfident/focus_blocking');
  final Map<String, Uint8List?> _art = {};

  Future<List<Song>> loadSongs() async {
    if (!Platform.isAndroid) return const [];
    final raw = await _ch.invokeMethod<List<Object?>>('getDeviceSongs') ?? const [];
    return raw.whereType<Map>().map((m) {
      return Song(
        id: 'd_${m['id']}',
        title: '${m['title']}',
        artist: '${m['artist']}',
        album: '${m['album'] ?? ''}',
        duration: Duration(milliseconds: (m['durationMs'] as num?)?.toInt() ?? 0),
        uri: '${m['uri']}',
      );
    }).toList();
  }

  /// Album art when Android has it (null otherwise). Cached per song.
  Future<Uint8List?> artwork(String uri) async {
    if (_art.containsKey(uri)) return _art[uri];
    Uint8List? bytes;
    try {
      bytes = await _ch.invokeMethod<Uint8List>('getSongArtwork', {'uri': uri});
    } on PlatformException {
      bytes = null;
    }
    _art[uri] = bytes;
    return bytes;
  }
}
