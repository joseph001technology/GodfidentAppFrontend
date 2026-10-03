import 'dart:io' show Platform;
import 'package:flutter/services.dart';

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

/// Songs bundled with Godfident. These are simple synthesized instrumentals:
/// two public-domain melodies (Beethoven's "Ode to Joy" and Gruber's "Silent
/// Night") and three original ambient pieces for prayer and rest.
const bundledSongs = <Song>[
  Song(id: 'a_quiet_morning', title: 'Quiet Morning', artist: 'Godfident', album: 'Rest', duration: Duration(seconds: 62), asset: 'assets/audio/quiet_morning.mp3'),
  Song(id: 'a_still_waters', title: 'Still Waters', artist: 'Godfident', album: 'Rest', duration: Duration(seconds: 68), asset: 'assets/audio/still_waters.mp3'),
  Song(id: 'a_evening_rest', title: 'Evening Rest', artist: 'Godfident', album: 'Rest', duration: Duration(seconds: 74), asset: 'assets/audio/evening_rest.mp3'),
  Song(id: 'a_ode_to_joy', title: 'Ode to Joy (Joyful, Joyful)', artist: 'Beethoven \u00b7 public domain', album: 'Hymns', duration: Duration(seconds: 37), asset: 'assets/audio/ode_to_joy.mp3'),
  Song(id: 'a_silent_night', title: 'Silent Night', artist: 'Gruber \u00b7 public domain', album: 'Hymns', duration: Duration(seconds: 43), asset: 'assets/audio/silent_night.mp3'),
];

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
